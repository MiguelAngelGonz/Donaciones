package com.donation.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.donation.app.data.PostType
import com.donation.app.ui.donation.DonationsScreen
import com.donation.app.ui.feed.FeedScreen
import com.donation.app.ui.profile.ProfileScreen

private enum class HomeTab(val label: String, val icon: ImageVector) {
    INICIO("Inicio", Icons.Default.Home),
    DONACIONES("Donaciones", Icons.Default.Favorite),
    PERFIL("Perfil", Icons.Default.Person)
}

/** Pantalla principal con tres pestañas: publicar y buscar, seguir donaciones y perfil (RNF-02). */
@Composable
fun HomeScreen(
    onOpenPost: (Long) -> Unit,
    onPublish: (PostType) -> Unit,
    onOpenDonation: (Long) -> Unit
) {
    var tab by rememberSaveable { mutableStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                HomeTab.entries.forEachIndexed { index, item ->
                    NavigationBarItem(
                        selected = tab == index,
                        onClick = { tab = index },
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) }
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            when (tab) {
                0 -> FeedScreen(onOpenPost = onOpenPost, onPublish = onPublish)
                1 -> DonationsScreen(onOpen = onOpenDonation)
                else -> ProfileScreen()
            }
        }
    }
}
