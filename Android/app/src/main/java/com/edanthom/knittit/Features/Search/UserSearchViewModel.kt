package com.edanthom.knittit.Features.Search

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.edanthom.knittit.Profile
import com.edanthom.knittit.Supabase
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class UserSearchViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(UserSearchUiState())
    val uiState: StateFlow<UserSearchUiState> = _uiState.asStateFlow()

    private var searchJob: Job? = null

    fun searchUsers(query: String) {
        searchJob?.cancel()
        
        if (query.isBlank()) {
            _uiState.value = UserSearchUiState(searchResults = emptyList())
            return
        }

        searchJob = viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            
            // Debounce
            delay(300)

            try {
                val results = Supabase.client.from("profiles")
                    .select {
                        filter {
                            ilike("username", "%$query%")
                        }
                        limit(20)
                    }.decodeList<Profile>()

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    searchResults = results
                )
            } catch (e: Exception) {
                Log.e("UserSearchViewModel", "Error searching users", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to search: ${e.message}"
                )
            }
        }
    }
}

data class UserSearchUiState(
    val isLoading: Boolean = false,
    val searchResults: List<Profile> = emptyList(),
    val error: String? = null
)