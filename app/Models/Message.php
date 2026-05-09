<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = [
        'report_id',
        'sender_id',
        'sender_name',
        'sender_role',
        'message',
        'is_read',
    ];

    public function report()
    {
        return $this->belongsTo(Report::class);
    }
}
