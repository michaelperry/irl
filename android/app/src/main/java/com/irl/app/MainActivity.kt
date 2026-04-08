package com.irl.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.irl.app.services.AuthService
import com.irl.app.ui.theme.IRLTheme

class MainActivity : ComponentActivity() {

    private lateinit var authService: AuthService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        authService = AuthService(this)

        setContent {
            IRLTheme {
                var isAuthenticated by remember { mutableStateOf(false) }

                IRLApp(
                    isAuthenticated = isAuthenticated,
                    onAuthRequest = {
                        authService.authenticate(
                            onSuccess = { isAuthenticated = true },
                            onError = { /* Handle error */ }
                        )
                    },
                    onLogout = { isAuthenticated = false }
                )
            }
        }
    }
}
