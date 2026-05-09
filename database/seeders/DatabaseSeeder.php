<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // User::factory(10)->create();

        // Guru BK 1
        User::updateOrCreate(
            ['email' => 'dini.setriani@sekolah.com'],
            [
                'name' => 'Dini Setriani, S.Pd., Gr',
                'password' => bcrypt('gurubk123'),
                'role' => 'teacher',
                'subject' => 'Bimbingan Konseling',
                'avatar' => 'DS',
            ]
        );

        // Guru BK 2
        User::updateOrCreate(
            ['email' => 'dede.yuliani@sekolah.com'],
            [
                'name' => 'Dede Yuliani, S.Psi., Gr',
                'password' => bcrypt('gurubk123'),
                'role' => 'teacher',
                'subject' => 'Bimbingan Konseling',
                'avatar' => 'DY',
            ]
        );

        // Guru BK 3
        User::updateOrCreate(
            ['email' => 'anis.novelia@sekolah.com'],
            [
                'name' => 'Anis Novelia Nurjanah, S.Psi., Gr',
                'password' => bcrypt('gurubk123'),
                'role' => 'teacher',
                'subject' => 'Bimbingan Konseling',
                'avatar' => 'AN',
            ]
        );
    }
}
