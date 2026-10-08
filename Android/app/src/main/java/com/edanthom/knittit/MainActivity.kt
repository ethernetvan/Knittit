package com.edanthom.knittit

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.tooling.preview.PreviewScreenSizes
import com.edanthom.knittit.Features.Login.AuthScreen
import com.edanthom.knittit.Features.Profile.ProfileScreen
import com.edanthom.knittit.Features.Search.UserSearchScreen
import com.edanthom.knittit.ui.theme.KnittitTheme
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KnittitTheme {
                KnittitApp()
            }
        }
    }
}

@PreviewScreenSizes
@Composable
fun KnittitApp() {
    var isLoggedIn by rememberSaveable { mutableStateOf(Supabase.client.auth.currentUserOrNull() != null) }

    if (!isLoggedIn) {
        AuthScreen(onLoginSuccess = { isLoggedIn = true })
    } else {
        var currentDestination by rememberSaveable { mutableStateOf(AppDestinations.HOME) }
        var viewingUserId by rememberSaveable { mutableStateOf<String?>(null) }
        var isSearching by rememberSaveable { mutableStateOf(false) }
        val coroutineScope = rememberCoroutineScope()

        if (isSearching) {
            UserSearchScreen(
                onNavigateBack = { isSearching = false },
                onUserClick = { userId ->
                    viewingUserId = userId
                    isSearching = false
                }
            )
        } else if (viewingUserId != null) {
             ProfileScreen(
                 userId = viewingUserId,
                 onSearchClick = {},
                 onSettingsClick = {}
             )
        } else {
            NavigationSuiteScaffold(
                navigationSuiteItems = {
                    AppDestinations.entries.forEach {
                        item(
                            icon = {
                                Icon(
                                    painterResource(it.icon),
                                    contentDescription = it.label
                                )
                            },
                            label = { Text(it.label) },
                            selected = it == currentDestination,
                            onClick = { currentDestination = it }
                        )
                    }
                }
            ) {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    when (currentDestination) {
                        AppDestinations.HOME -> {
                            Greeting(
                                name = "Home",
                                modifier = Modifier.padding(innerPadding)
                            )
                        }
                        AppDestinations.FAVORITES -> {
                            Greeting(
                                name = "Favorites",
                                modifier = Modifier.padding(innerPadding)
                            )
                        }
                        AppDestinations.PROFILE -> {
                            ProfileScreen(
                                userId = null, // null means current user
                                onSearchClick = { isSearching = true },
                                onSettingsClick = {
                                    coroutineScope.launch {
                                        try {
                                            Supabase.client.auth.signOut()
                                            isLoggedIn = false
                                        } catch (e: Exception) {
                                            // Handle error
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

enum class AppDestinations(
    val label: String,
    val icon: Int,
) {
    HOME("Home", R.drawable.ic_home),
    FAVORITES("Favorites", R.drawable.ic_favorite),
    PROFILE("Profile", R.drawable.ic_account_box),
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "Hello $name!",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    KnittitTheme {
        Greeting("Android")
    }
}