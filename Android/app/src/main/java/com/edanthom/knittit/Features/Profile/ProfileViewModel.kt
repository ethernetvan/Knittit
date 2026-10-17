package com.edanthom.knittit.Features.Profile

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.edanthom.knittit.Profile
import com.edanthom.knittit.Project
import com.edanthom.knittit.Supabase
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ProfileViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    fun loadProfileData(userId: String? = null) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                // Determine which user ID to load. If none is passed, use the current logged-in user.
                val targetUserId = userId ?: Supabase.client.auth.currentUserOrNull()?.id
                
                if (targetUserId == null) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = "User not logged in."
                    )
                    return@launch
                }

                val profile = Supabase.client.from("profiles")
                    .select {
                        filter {
                            eq("id", targetUserId)
                        }
                    }.decodeSingle<Profile>()

                val projects = Supabase.client.from("projects")
                    .select {
                        filter {
                            eq("user_id", targetUserId)
                        }
                    }.decodeList<Project>()

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    profile = profile,
                    projects = projects
                )
            } catch (e: Exception) {
                Log.e("ProfileViewModel", "Error fetching profile", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to load profile: ${e.message}"
                )
            }
        }
    }
}

data class ProfileUiState(
    val isLoading: Boolean = false,
    val profile: Profile? = null,
    val projects: List<Project> = emptyList(),
    val error: String? = null
)