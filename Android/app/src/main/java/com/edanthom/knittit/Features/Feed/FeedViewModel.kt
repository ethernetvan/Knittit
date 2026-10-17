package com.edanthom.knittit.Features.Feed

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.edanthom.knittit.Profile
import com.edanthom.knittit.Project
import com.edanthom.knittit.Supabase
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class FeedItem(
    val project: Project,
    val profile: Profile
)

data class FeedUiState(
    val isLoading: Boolean = false,
    val feedItems: List<FeedItem> = emptyList(),
    val error: String? = null
)

class FeedViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(FeedUiState())
    val uiState: StateFlow<FeedUiState> = _uiState.asStateFlow()

    init {
        loadFeed()
    }

    fun loadFeed() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                // Fetch the latest projects
                val projects = Supabase.client.from("projects")
                    .select {
                        order("created_at", order = Order.DESCENDING)
                        limit(50)
                    }.decodeList<Project>()

                if (projects.isEmpty()) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        feedItems = emptyList()
                    )
                    return@launch
                }

                // Extract unique user IDs from the projects
                val userIds = projects.map { it.userId }.distinct()

                // Fetch the profiles for these users
                val profiles = Supabase.client.from("profiles")
                    .select {
                        filter {
                            isIn("id", userIds)
                        }
                    }.decodeList<Profile>()

                val profileMap = profiles.associateBy { it.id }

                // Combine projects and profiles
                val feedItems = projects.mapNotNull { project ->
                    profileMap[project.userId]?.let { profile ->
                        FeedItem(project = project, profile = profile)
                    }
                }

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    feedItems = feedItems
                )
            } catch (e: Exception) {
                Log.e("FeedViewModel", "Error fetching feed", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to load feed: ${e.message}"
                )
            }
        }
    }
}
