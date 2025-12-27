
const STOP_WORDS = new Set([
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'have', 'has', 'had',
    'was', 'were', 'will', 'would', 'could', 'should', 'about', 'into', 'onto',
    'your', 'you', 'they', 'their', 'them', 'then', 'than', 'are', 'but', 'not',
    'all', 'any', 'some', 'very', 'just', 'over', 'under', 'more', 'most', 'few',
    'our', 'out', 'per', 'its', 'it', 'in', 'on', 'of', 'at', 'to', 'by', 'or',
    'as', 'is', 'be', 'been', 'an', 'a'
]);

function parseReflectionsFromPrompt(prompt) {
    const lines = prompt.split('\n');
    const reflections = [];
    const regex = /^-\s*\[(.+?)\]\s*\((\d+)\s*mins\):\s*(.*)$/;

    for (const line of lines) {
        const match = regex.exec(line.trim());
        if (match) {
            reflections.push({
                dateLabel: match[1],
                durationMinutes: Number(match[2]) || 0,
                text: match[3].trim(),
            });
        }
    }

    return reflections;
}

function extractCourseFromPrompt(prompt) {
    const match = prompt.match(/study patterns for (.*)\./i);
    return match?.[1]?.trim() || 'your course';
}

function extractPeriodLabel(prompt) {
    const match = prompt.match(/last (.*):/i);
    return match?.[1]?.trim() || 'recent period';
}

function extractTopTopics(reflections) {
    const counts = new Map();
    const wordRegex = /[A-Za-z][A-Za-z0-9'+-]{2,}/g;

    for (const ref of reflections) {
        const matches = ref.text.toLowerCase().match(wordRegex) || [];
        for (const word of matches) {
            if (word.length <= 3 || STOP_WORDS.has(word)) {
                continue;
            }
            counts.set(word, (counts.get(word) ?? 0) + 1);
        }
    }

    const sorted = Array.from(counts.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3);

    if (sorted.length === 0) {
        return [
            { name: 'Study session', category: 'General', count: reflections.length || 1 },
        ];
    }

    return sorted.map(([word, count]) => ({
        name: word.charAt(0).toUpperCase() + word.slice(1),
        category: 'Theme',
        count,
    }));
}

function buildFallbackAnalysis(prompt) {
    const reflections = parseReflectionsFromPrompt(prompt);
    const courseName = extractCourseFromPrompt(prompt);
    const periodLabel = extractPeriodLabel(prompt);
    const totalSessions = reflections.length;
    const totalMinutes = reflections.reduce((sum, r) => sum + r.durationMinutes, 0);
    const averageMinutes = totalSessions > 0 ? Math.round(totalMinutes / totalSessions) : 0;
    const nonEmptyNotes = reflections.filter(r => r.text.length > 0).length;
    const topTopics = extractTopTopics(reflections);

    const topicNames = topTopics.map(t => t.name).join(', ');
    const summaryParts = [];

    summaryParts.push(
        totalSessions > 0
            ? `You logged ${totalSessions} reflection${totalSessions === 1 ? '' : 's'} in the ${periodLabel} for ${courseName}.`
            : `No reflections captured for ${courseName} in the ${periodLabel}.`
    );

    summaryParts.push(
        totalMinutes > 0
            ? `About ${totalMinutes} minutes recorded (${averageMinutes} mins on average).`
            : 'Study durations are missing, so total time is unclear.'
    );

    if (nonEmptyNotes > 0) {
        summaryParts.push(`Your notes often mention: ${topicNames}.`);
    } else {
        summaryParts.push('Most reflections lack comments; add a quick note after each study block.');
    }

    summaryParts.push('These insights are offline because the AI service is not configured yet.');

    const patterns = [];
    if (totalSessions >= 3) {
        patterns.push(`Regular reflections (${totalSessions} entries).`);
    } else if (totalSessions > 0) {
        patterns.push('Reflections are sporadic; adding a few more will reveal clearer trends.');
    }
    if (totalMinutes > 0) {
        patterns.push(`Total logged time: ${totalMinutes} mins.`);
    }
    if (averageMinutes > 0) {
        patterns.push(`Average session length: ${averageMinutes} mins.`);
    }

    const weakSpots = [];
    if (totalSessions < 3) {
        weakSpots.push('Limited data; add more reflections to improve insights.');
    }
    if (nonEmptyNotes === 0) {
        weakSpots.push('Reflections have no detailed comments.');
    }
    if (totalMinutes === 0) {
        weakSpots.push('Study durations are not recorded.');
    }

    const recommendations = [
        {
            text: 'Add a short note after each session to capture what you covered.',
            type: 'Habit',
        },
        {
            text: totalMinutes === 0
                ? 'Record the minutes for each study block to track progress.'
                : `Plan a focused ${Math.max(25, averageMinutes || 25)}-minute session on ${topTopics[0].name.toLowerCase()}.`,
            type: 'Action',
        },
        {
            text: 'Tag reflections with key topics (e.g., formulas, proofs, practice) to surface better patterns.',
            type: 'Organize',
        },
    ];

    return {
        summary: summaryParts.join(' '),
        topTopics,
        patterns: patterns.length ? patterns : ['Recent study activity detected.'],
        weakSpots: weakSpots.length ? weakSpots : ['Keep logging reflections to refine insights.'],
        recommendations,
        motivationalMessage: 'Small, consistent notes add up—keep going!',
    };
}

const prompt = `
Study sessions for the last Last 1 Month:
- [2025-12-16 01:02:44.589] (1 mins): Integrals
- [2025-12-10 21:40:57.993] (1 mins): Derivatives
- [2025-12-10 21:40:47.076] (1 mins): Lhopital
- [2025-12-10 21:40:39.863] (1 mins): Limits
- [2025-12-10 21:40:16.274] (1 mins): Math
- [2025-12-08 16:55:56.444] (1 mins): Integrating by u substitutuing
- [2025-12-08 16:55:38.049] (1 mins): Derivatives by chain rule
- [2025-12-08 16:54:20.576] (1 mins): Implicit differentiation
- [2025-12-08 16:54:06.352] (1 mins): functions
- [2025-12-08 16:52:59.160] (1 mins): Derivatives

You are an AI study coach analyzing a student's study patterns for math.
`;

const result = buildFallbackAnalysis(prompt);
console.log(JSON.stringify(result, null, 2));
console.log("Length:", JSON.stringify(result).length);
