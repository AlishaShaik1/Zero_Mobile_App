import { NextRequest, NextResponse } from 'next/server';
import { serperSearch, formatSearchResults } from '@/lib/search/serper';

export const runtime = 'edge';

export async function GET(req: NextRequest) {
    try {
        const { searchParams } = new URL(req.url);
        const query = searchParams.get('q') || searchParams.get('query');
        const limit = parseInt(searchParams.get('limit') || '5', 10);

        if (!query) {
            return NextResponse.json({ error: 'Missing search query (?q=...)' }, { status: 400 });
        }

        const results = await serperSearch(query, limit);
        const formatted = formatSearchResults(results);

        return NextResponse.json({
            count: results.length,
            query,
            results,
            formatted,
        });
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 });
    }
}

export async function POST(req: NextRequest) {
    try {
        const body = await req.json();
        const query = body.query || body.q;
        const limit = body.limit || 5;

        if (!query) {
            return NextResponse.json({ error: 'No query provided' }, { status: 400 });
        }

        const results = await serperSearch(query, limit);
        const formatted = formatSearchResults(results);

        return NextResponse.json({
            count: results.length,
            query,
            results,
            formatted,
        });
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 });
    }
}
