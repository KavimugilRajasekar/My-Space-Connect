package com.example.my_space_connect

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle
import androidx.multidex.MultiDex

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MultiDex.install(this)
    }
}