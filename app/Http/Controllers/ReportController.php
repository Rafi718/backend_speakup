<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Report;
use App\Models\Message;

class ReportController extends Controller
{
    // GET /api/reports - Get all reports (for teachers)
    public function index(Request $request)
    {
        // Sort by newest first
        $reports = Report::with(['user', 'messages'])->orderBy('created_at', 'desc')->get()->map(function ($report) {
            return $this->formatReport($report);
        });

        return response()->json($reports);
    }

    // GET /api/students/{id}/reports - Get reports for a specific student
    public function getByStudent($studentId)
    {
        $reports = Report::with(['user', 'messages'])
            ->where('user_id', $studentId)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(function ($report) {
                return $this->formatReport($report);
            });

        return response()->json($reports);
    }

    // GET /api/reports/{id} - Get single report detail
    public function show($id)
    {
        $report = Report::with(['user', 'messages'])->findOrFail($id);
        return response()->json($this->formatReport($report));
    }

    // POST /api/reports - Create new report
    public function store(Request $request)
    {
        $request->validate([
            'content' => 'required|string',
            'studentId' => 'required',
        ]);

        // Basic AI mock score since frontend originally did it
        // Or we can just let frontend pass riskLevel and keywords if needed, but the prompt says 
        // the payload has `content, categories, mood, studentId`.
        
        $report = Report::create([
            'user_id' => $request->studentId,
            'category' => $request->categories ?? [],
            'content' => $request->content,
            'feeling' => $request->mood,
            'status' => 'new',
            'notes' => null,
        ]);

        return response()->json($this->formatReport($report), 201);
    }

    // PUT /api/reports/{id}/status - Update status
    public function updateStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:new,in-progress,resolved'
        ]);

        $report = Report::findOrFail($id);
        $report->status = $request->status;
        $report->save();

        return response()->json($this->formatReport($report));
    }

    // PUT /api/reports/{id}/notes - Update notes
    public function updateNotes(Request $request, $id)
    {
        $request->validate([
            'notes' => 'nullable|string'
        ]);

        $report = Report::with(['user', 'messages'])->findOrFail($id);
        $report->notes = $request->notes;
        $report->save();

        return response()->json($this->formatReport($report));
    }

    // POST /api/reports/{id}/messages - Send a message
    public function storeMessage(Request $request, $id)
    {
        $request->validate([
            'senderId' => 'required',
            'senderName' => 'required',
            'senderRole' => 'required',
            'message' => 'required',
        ]);

        $report = Report::findOrFail($id);
        
        $message = Message::create([
            'report_id' => $report->id,
            'sender_id' => $request->senderId,
            'sender_name' => $request->senderName,
            'sender_role' => $request->senderRole,
            'message' => $request->message,
            'is_read' => false,
        ]);

        return response()->json($message, 201);
    }

    // PUT /api/reports/{id}/messages/read - Mark messages as read
    public function markMessagesRead(Request $request, $id)
    {
        $request->validate([
            'userId' => 'required'
        ]);

        $report = Report::findOrFail($id);
        
        // If current user is student, mark counselor messages as read, vice versa.
        // We'll just mark all unread messages in the report as read for simplicity if requested.
        Message::where('report_id', $report->id)
               ->where('sender_id', '!=', $request->userId)
               ->update(['is_read' => true]);

        return response()->json(['success' => true]);
    }

    // Format the eloquent model to match the frontend Report interface
    private function formatReport(Report $report)
    {
        $analysis = $this->analyzeContent($report->content);

        return [
            'id' => (string) $report->id,
            'studentId' => (string) $report->user_id,
            // Fallback user details if relation isn't loaded or user is deleted
            'studentClass' => $report->user ? $report->user->class : 'Unknown',
            'studentInitial' => $report->user ? $report->user->avatar : 'Anon',
            'content' => $report->content,
            'categories' => $report->category ?? [],
            'mood' => $report->feeling,
            'timestamp' => $report->created_at->toISOString(),
            'date' => $report->created_at->format('d M Y'),
            'time' => $report->created_at->format('H:i'),
            'status' => $report->status,
            'notes' => $report->notes,
            // Dynamically computed AI fields
            'riskLevel' => $analysis['riskLevel'], 
            'sentiment' => $analysis['sentiment'],
            'aiScore' => $analysis['aiScore'],
            'keywords' => $analysis['keywords'],
            'location' => 'Tidak disebutkan',
            'witness' => false,
            'messages' => $report->messages ? $report->messages->map(function ($msg) {
                return [
                    'id' => (string) $msg->id,
                    'senderId' => $msg->sender_id,
                    'senderName' => $msg->sender_name,
                    'senderRole' => $msg->sender_role,
                    'message' => $msg->message,
                    'timestamp' => $msg->created_at->toISOString(),
                    'isRead' => (bool) $msg->is_read,
                ];
            })->toArray() : [],
        ];
    }

    private function analyzeContent($content)
    {
        $negativeKeywords = [
            'ejek', 'hina', 'maki', 'kasar', 'bodoh', 'goblok', 'tolol', 'jelek', 
            'buruk', 'cacian', 'ancam', 'takut', 'cela', 'sindir', 'ledek',
            'rendah', 'miskin', 'kaya', 'sok', 'pansos', 'attention', 'norak', 'ngetawain',
            'chat', 'whatsapp', 'instagram', 'medsos', 'online', 
            'posting', 'status', 'story', 'komen', 'tiktok',
            'twitter', 'facebook', 'snapchat', 'grup', 'broadcast', 'viral',
            'screenshot', 'share', 'forward', 'blast', 'spam',
            'pukul', 'tendang', 'tampar', 'dorong', 'sikut', 'jambak', 'ikat',
            'kunci', 'peras', 'rampas', 'ambil', 'paksa', 'maksa', 'ancam', 'intimidasi',
            'kekerasan', 'luka', 'sakit', 'bengkak', 'memar', 'berdarah', 'patah',
            'narik tas', 'uang jajan', 'palak', 'malak',
            'kucil', 'asingkan', 'acuh', 'diamkan', 'sendirian', 'sendiri', 'diabaikan',
            'tidak dihiraukan', 'tidak diajak', 'tidak diterima', 'dijauhi', 'dihindari',
            'terpencil', 'terisolasi', 'tidak punya teman', 'kesepian', 'dikecualikan',
            'sedih', 'trauma', 'depresi', 'stres', 'cemas', 'khawatir',
            'menangis', 'menyendiri', 'tidak mood', 'galau', 'insecure',
            'minder', 'tidak percaya diri', 'malu', 'terhina', 'tersakiti', 'sakit hati',
            'bunuh diri', 'mengakhiri', 'tidak ingin hidup', 'capek', 'lelah',
            'bully', 'bullying', 'perundungan', 'penindasan', 'pelecehan', 'diskriminasi',
            'rasisme', 'seksisme', 'body shaming', 'tidak adil', 'tidak nyaman',
            'terintimidasi', 'terancam', 'bahaya', 'korban', 'pelaku', 'saksi'
        ];

        $positiveKeywords = [
            'terima kasih', 'terimakasih', 'aman', 'tenang', 'senang', 'baik',
            'baikan', 'lega', 'semangat', 'mendukung', 'membantu', 'sudah baik',
            'sudah membaik', 'bangga', 'percaya diri', 'nyaman', 'berteman',
            'teman baru', 'damai', 'happy', 'bersyukur', 'harapan', 'pulih'
        ];

        $detectedNegative = [];
        foreach ($negativeKeywords as $keyword) {
            if (strlen($keyword) < 3) continue;
            $pattern = '/\b' . preg_quote($keyword, '/') . '\b/i';
            if (preg_match($pattern, $content)) {
                $detectedNegative[] = $keyword;
            }
        }

        $detectedPositive = [];
        foreach ($positiveKeywords as $keyword) {
            $pattern = '/\b' . preg_quote($keyword, '/') . '\b/i';
            if (preg_match($pattern, $content)) {
                $detectedPositive[] = $keyword;
            }
        }

        $negCount = count($detectedNegative);
        $posCount = count($detectedPositive);
        $aiScore = max(0, min(100, ($negCount * 15) - ($posCount * 5)));
        
        $riskLevel = 'low';
        $sentiment = 'neutral';
        
        if ($posCount > $negCount) {
            $sentiment = 'positive';
            $riskLevel = 'low';
        } elseif ($negCount > 5) {
            $riskLevel = 'critical';
            $sentiment = 'negative';
        } elseif ($negCount > 2) {
            $riskLevel = 'high';
            $sentiment = 'negative';
        } elseif ($negCount > 0) {
            $riskLevel = 'medium';
            $sentiment = 'negative';
        }

        return [
            'keywords'         => $detectedNegative,
            'positiveKeywords' => $detectedPositive,
            'aiScore'          => $aiScore,
            'riskLevel'        => $riskLevel,
            'sentiment'        => $sentiment,
        ];
    }
}
