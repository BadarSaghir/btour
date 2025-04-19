const fs = require('fs');
const path = require('path');

const markdownFilePath = process.argv[2]; // Get Markdown file path from command line argument

if (!markdownFilePath) {
    console.error('Usage: node create_files.js <path_to_markdown_file.md>');
    process.exit(1);
}

if (!fs.existsSync(markdownFilePath)) {
    console.error(`Error: Markdown file not found at ${markdownFilePath}`);
    process.exit(1);
}

console.log(`Processing Markdown file: ${markdownFilePath}`);

try {
    const markdownContent = fs.readFileSync(markdownFilePath, 'utf-8');

    // Regex to find Dart code blocks with the file marker
    //