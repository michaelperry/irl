package com.irl.app

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.irl.app.ui.screens.LoginScreen
import com.irl.app.ui.screens.MainScreen

@Composable
fun IRLApp(
    isAuthenticated: Boolean,
    onAuthRequest: () -> Unit,
    onLogout: () -> Unit
) {
    val navController = rememberNavController()
    val startDestination = if (isAuthenticated) "main" else "login"

    NavHost(
        navController = navController,
        startDestination = startDestination,
        enterTransition = { fadeIn(animationSpec = tween(400)) },
        exitTransition = { fadeOut(animationSpec = tween(400)) }
    ) {
        composable("login") {
            LoginScreen(
                onSignIn = onAuthRequest
            )
        }

        composable("main") {
            MainScreen(
                onLogout = onLogout
            )
        }
    }
}
