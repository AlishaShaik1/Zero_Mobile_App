const ZERO_SEARCH_URL = process.env.ZERO_SEARCH_URL || 'https://zero-gpu-server.vercel.app/api/search';
const SERPER_API_KEY = process.env.SERPER_API_KEY;

export interface SearchResult {
    title: string;
    snippet: string;
    link: string;
    source?: string;
}

/**
 * Searches the web using Zero Labs Live Real-Time Web Search Engine API
 * (sub-500ms latency, unblocked global feeds).
 */
export async function serperSearch(query: string, numResults = 5): Promise<SearchResult[]> {
    try {
        const url = `${ZERO_SEARCH_URL}?q=${encodeURIComponent(query)}&limit=${numResults}`;
        const res = await fetch(url, {
            method: 'GET',
            headers: {
                'Accept': 'application/json',
            },
            cache: 'no-store',
        });

        if (res.ok) {
            const data = await res.json();
            if (data && Array.isArray(data.results) && data.results.length > 0) {
                return data.results.slice(0, numResults).map((r: any) => ({
                    title: r.title ?? '',
                    snippet: r.snippet ?? '',
                    link: r.url ?? r.link ?? '',
                    source: r.source ?? '',
                }));
            }
        }
    } catch (err) {
        console.warn('Zero Labs Web Search API warning:', err);
    }

    // Secondary fallback to Serper if key available
    if (SERPER_API_KEY && SERPER_API_KEY !== 'your_serper_api_key_here') {
        try {
            const res = await fetch('https://google.serper.dev/search', {
                method: 'POST',
                headers: {
                    'X-API-KEY': SERPER_API_KEY,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ q: query, num: numResults }),
            });

            if (res.ok) {
                const data = await res.json();
                return (data.organic ?? []).slice(0, numResults).map((r: any) => ({
                    title: r.title ?? '',
                    snippet: r.snippet ?? '',
                    link: r.link ?? '',
                    source: 'Google Search',
                }));
            }
        } catch (e) {
            console.error('Serper fallback error:', e);
        }
    }

    return [];
}

export function formatSearchResults(results: SearchResult[]): string {
    if (!results || results.length === 0) {
        return 'No live search results found.';
    }
    return results
        .map((r, i) => `[${i + 1}] ${r.title}\n${r.snippet}\nSource: ${r.link || r.source || 'Web'}`)
        .join('\n\n');
}
