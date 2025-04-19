
// FILE: create_files.js
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
    // ```dart              -> Start of block (allowing spaces after ```)
    // // FILE: (.*?)       -> File marker line, captures the path non-greedily
    // \s*?\n               -> Optional space and newline after marker
    // ([\s\S]*?)           -> Capture the actual code (including newlines) non-greedily
    // ```                  -> End of block
    const codeBlockRegex = /```markdown\s*\/\/\s*FILE:\s*(.*?)\s*?\n([\s\S]*?)```/g;

    let match;
    let filesCreated = 0;

    while ((match = codeBlockRegex.exec(markdownContent)) !== null) {
        const relativeFilePath = match[1].trim();
        let codeContent = match[2].trim();

        if (!relativeFilePath) {
            console.warn('Found Dart code block without a valid // FILE: marker. Skipping.');
            continue;
        }

        // Make the path relative to the script's execution directory or a specific base dir
        const absoluteFilePath = path.resolve(process.cwd(), relativeFilePath);
        const directoryPath = path.dirname(absoluteFilePath);

        try {
            // Create directories recursively if they don't exist
            if (!fs.existsSync(directoryPath)) {
                fs.mkdirSync(directoryPath, { recursive: true });
                console.log(`Created directory: ${directoryPath}`);
            }

            // Write the code content to the file
            fs.writeFileSync(absoluteFilePath, codeContent, 'utf-8');
            console.log(`Successfully wrote file: ${absoluteFilePath}`);
            filesCreated++;

        } catch (err) {
            console.error(`Error processing file ${relativeFilePath}:`, err);
        }
    }

    if (filesCreated > 0) {
         console.log(`\n✅ Successfully created ${filesCreated} files.`);
    } else {
         console.log('\n⚠️ No Flutter/Dart code blocks with valid "// FILE: path/to/file.dart" markers found.');
    }


} catch (err) {
    console.error('Error reading or processing Markdown file:', err);
    process.exit(1);
}