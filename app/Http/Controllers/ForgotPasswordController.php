<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use App\Models\User;

class ForgotPasswordController extends Controller
{
    /**
     * Send a password reset link to the given email.
     * 
     * Since we use a React SPA frontend, we manually generate the token
     * and construct the reset URL pointing to the frontend route,
     * bypassing Laravel's default named route 'password.reset'.
     */
    public function sendResetLink(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        // Check if user exists
        $user = User::where('email', $request->email)->first();
        if (!$user) {
            // For security, don't reveal whether the email exists
            return response()->json([
                'message' => 'Jika email terdaftar, link reset password telah dikirim ke email Anda.',
            ]);
        }

        // Generate token manually
        $token = Str::random(64);

        // Delete any existing tokens for this email
        DB::table('password_reset_tokens')->where('email', $request->email)->delete();

        // Insert new token
        DB::table('password_reset_tokens')->insert([
            'email' => $request->email,
            'token' => Hash::make($token),
            'created_at' => now(),
        ]);

        // Build the frontend reset URL
        $frontendUrl = env('FRONTEND_URL', 'http://localhost:5173');
        $resetUrl = $frontendUrl . '/reset-password?token=' . $token . '&email=' . urlencode($request->email);

        // In production, you would send this via email.
        // For development, we log it and return it in the response.
        \Log::info('Password reset URL: ' . $resetUrl);

        return response()->json([
            'message' => 'Jika email terdaftar, link reset password telah dikirim ke email Anda.',
            // Include reset URL in response for development/testing
            'reset_url' => $resetUrl,
        ]);
    }

    /**
     * Reset the user's password using a valid token.
     */
    public function resetPassword(Request $request)
    {
        $request->validate([
            'token' => 'required',
            'email' => 'required|email',
            'password' => 'required|string|min:8|confirmed',
        ]);

        // Find the reset token record
        $record = DB::table('password_reset_tokens')
            ->where('email', $request->email)
            ->first();

        if (!$record) {
            throw ValidationException::withMessages([
                'email' => ['Token reset password tidak ditemukan atau sudah kedaluwarsa.'],
            ]);
        }

        // Check if token has expired (60 minutes)
        if (now()->diffInMinutes($record->created_at) > 60) {
            DB::table('password_reset_tokens')->where('email', $request->email)->delete();
            throw ValidationException::withMessages([
                'email' => ['Token reset password sudah kedaluwarsa. Silakan minta link baru.'],
            ]);
        }

        // Verify the token
        if (!Hash::check($request->token, $record->token)) {
            throw ValidationException::withMessages([
                'email' => ['Token reset password tidak valid.'],
            ]);
        }

        // Find user and update password
        $user = User::where('email', $request->email)->first();
        if (!$user) {
            throw ValidationException::withMessages([
                'email' => ['User tidak ditemukan.'],
            ]);
        }

        $user->forceFill([
            'password' => Hash::make($request->password),
        ])->save();

        // Delete the used token
        DB::table('password_reset_tokens')->where('email', $request->email)->delete();

        return response()->json([
            'message' => 'Password berhasil direset. Silakan login dengan password baru.',
        ]);
    }
}
