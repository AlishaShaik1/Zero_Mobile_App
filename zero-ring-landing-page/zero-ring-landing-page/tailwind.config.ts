import type { Config } from 'tailwindcss';
import typography from '@tailwindcss/typography';

const config: Config = {
    content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
    darkMode: 'class',
    plugins: [typography],
};

export default config;
