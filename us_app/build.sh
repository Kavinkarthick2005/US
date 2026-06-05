#!/bin/bash
export PATH="$PATH:`pwd`/flutter/bin"
echo "class Env{static const supabaseUrl='$SUPABASE_URL';static const supabaseAnonKey='$SUPABASE_ANON_KEY';static const groqApiKey='$GROQ_API_KEY';static const clarifaiKey='$CLARIFAI_KEY';}">lib/config/env.dart
flutter build web --release
