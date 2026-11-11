package com.donation.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.donation.app.DonationApp
import com.donation.app.ui.auth.LoginScreen
import com.donation.app.ui.auth.RegisterScreen
import com.donation.app.ui.donation.DonationDetailScreen
import com.donation.app.ui.post.PostDetailScreen
import com.donation.app.ui.publish.PublishScreen

private const val LOGIN = "login"
private const val REGISTER = "register"
private const val HOME = "home"
private const val PUBLISH = "publish/{type}"
private const val POST = "post/{postId}"
private const val DONATION = "donation/{donationId}"

@Composable
fun AppNavigation() {
    val context = LocalContext.current
    val session = (context.applicationContext as DonationApp).container.session
    val navController = rememberNavController()
    val userId by session.userId.collectAsState()
    val startDestination = remember { if (session.currentUserId != null) HOME else LOGIN }

    NavHost(navController = navController, startDestination = startDestination) {
        composable(LOGIN) {
            LoginScreen(onGoRegister = { navController.navigate(REGISTER) })
        }
        composable(REGISTER) {
            RegisterScreen(onBack = { navController.popBackStack() })
        }
        composable(HOME) {
            HomeScreen(
                onOpenPost = { id -> navController.navigate("post/$id") },
                onPublish = { type -> navController.navigate("publish/${type.name}") },
                onOpenDonation = { id -> navController.navigate("donation/$id") }
            )
        }
        composable(
            route = PUBLISH,
            arguments = listOf(navArgument("type") { type = NavType.StringType })
        ) {
            PublishScreen(onBack = { navController.popBackStack() })
        }
        composable(
            route = POST,
            arguments = listOf(navArgument("postId") { type = NavType.LongType })
        ) {
            PostDetailScreen(
                onBack = { navController.popBackStack() },
                // Al aceptar una solicitud se pasa a la donación y se quita el detalle de la pila.
                onOpenDonation = { id ->
                    navController.navigate("donation/$id") {
                        popUpTo(POST) { inclusive = true }
                    }
                }
            )
        }
        composable(
            route = DONATION,
            arguments = listOf(navArgument("donationId") { type = NavType.LongType })
        ) {
            DonationDetailScreen(onBack = { navController.popBackStack() })
        }
    }

    // Abrir o cerrar sesión lleva a la pantalla que corresponde y limpia el historial de pantallas.
    LaunchedEffect(userId) {
        val current = navController.currentDestination?.route ?: return@LaunchedEffect
        val onAuthScreen = current == LOGIN || current == REGISTER
        if (userId == null && !onAuthScreen) {
            navController.navigate(LOGIN) {
                popUpTo(navController.graph.id) { inclusive = true }
            }
        } else if (userId != null && onAuthScreen) {
            navController.navigate(HOME) {
                popUpTo(navController.graph.id) { inclusive = true }
            }
        }
    }
}
