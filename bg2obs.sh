#!/bin/bash

usage() {
  echo "Usage: $0 [-beaicyh] [-v version]"
  echo "  -v version   Specify the translation to download (default = WEB)"
  echo "  -b    Set words of Jesus in bold"
  echo "  -e    Include editorial headers"
  echo "  -a    Create an alias in the YAML front matter for each chapter title"
  echo "  -i    Show download information (i.e. verbose mode)"
  echo "  -c    Include inline navigation for the breadcrumbs plugin (e.g. 'up', 'next','previous')"
  echo "  -y    Print navigation for the breadcrumbs plugin (e.g. 'up', 'next','previous') in the frontmatter (YAML)"
  echo "  -h    Display help"
  exit 1
}

translation='NKJV'
boldwords=false
headers=false
verbose=true
breadcrumbs_inline=true

while getopts 'v:beaicyh' c; do
  case $c in
    v) translation=$OPTARG ;;
    b) boldwords=true ;;
    e) headers=true ;;
    i) verbose=true ;;
    c) breadcrumbs_inline=true ;;
    h|?) usage ;;
  esac
done

biblename="The Bible"
biblefolder="${biblename} (${translation})"
bookarray=(Genesis Exodus Leviticus Numbers Deuteronomy Joshua Judges Ruth "1 Samuel" "2 Samuel" "1 Kings" "2 Kings" "1 Chronicles" "2 Chronicles" Ezra Nehemiah Esther Job Psalms Proverbs Ecclesiastes "Song of Solomon" Isaiah Jeremiah Lamentations Ezekiel Daniel Hosea Joel Amos Obadiah Jonah Micah Nahum Habakkuk Zephaniah Haggai Zechariah Malachi Matthew Mark Luke John Acts Romans "1 Corinthians" "2 Corinthians" Galatians Ephesians Philippians Colossians "1 Thessalonians" "2 Thessalonians" "1 Timothy" "2 Timothy" Titus Philemon Hebrews James "1 Peter" "2 Peter" "1 John" "2 John" "3 John" Jude Revelation)
lengtharray=(50 40 27 36 34 24 21 4 31 24 22 25 29 36 10 13 10 42 150 31 12 8 66 52 5 48 12 14 3 9 1 4 7 3 3 3 2 14 4 28 16 24 21 28 16 16 13 6 6 4 4 5 3 6 4 3 1 13 5 5 3 5 1 1 1 22)

# Initialize the main index file
index_file="./${biblefolder}/The Bible.md"
echo "# The Bible" > "$index_file"

for book_index in "${!bookarray[@]}"; do
    book="${bookarray[$book_index]}"
    maxchapter="${lengtharray[$book_index]}"
    folder_name="./${biblefolder}/${book}"
    mkdir -p "$folder_name"

    # Create a main book page with a single link to the first chapter
    echo "# $book" > "$folder_name/$book.md"
    echo "[[$book 1|Start Reading →]]" > "$folder_name/$book.md"

    # Add book to main index file
    echo -n "**[[$book]]:** " >> "$index_file"

    for ((chapter=1; chapter <= maxchapter; chapter++)); do
        filename="${book} ${chapter}.md"
        file_path="$folder_name/$filename"
        temp_file_path="$folder_name/temp_$filename"
        ruby_command="ruby bg2md.rb -v \"$translation\" \"$book $chapter\" > \"$folder_name/$filename\""

        if [ "$verbose" = true ]; then
            echo "Downloading: $book $chapter"
            echo "$ruby_command"
        fi

        eval "$ruby_command"

        # Add this chapter to the main index file
        echo -n " [[$filename|$chapter]]" >> "$index_file"

        # Write the YAML front matter to the temporary file first
        echo -e "---\ncssclass: \"bible\"\n---" > "$temp_file_path"

        # Initialize breadcrumb links with checks for first and last chapters
        if [ $chapter -eq 1 ]; then
            prev_link=""
            next_link=$([ $chapter -lt $maxchapter ] && echo "[[$book $((chapter+1))|$book $((chapter+1)) →]]" || echo "")
        elif [ $chapter -eq $maxchapter ]; then
            prev_link=$([ $chapter -gt 1 ] && echo "[[$book $((chapter-1))|← $book $((chapter-1))]]" || echo "")
            next_link=""
        else
            prev_link=$([ $chapter -gt 1 ] && echo "[[$book $((chapter-1))|← $book $((chapter-1))]]" || echo "")
            next_link=$([ $chapter -lt $maxchapter ] && echo "[[$book $((chapter+1))|$book $((chapter+1)) →]]" || echo "")
        fi

        book_link="[[$book|$book]]"

        # Format breadcrumbs with dividers correctly positioned
        breadcrumbs_top="\n$prev_link $([ -n "$prev_link" ] && echo "| ")$book_link$([ -n "$next_link" ] && echo " | ")$next_link\n\n---\n"
        breadcrumbs_bottom="\n---\n\n$prev_link $([ -n "$prev_link" ] && echo "| ")$book_link$([ -n "$next_link" ] && echo " | ")$next_link"
        
        # Prepend and append breadcrumbs to the top and bottom of the file
        echo -e "$breadcrumbs_top" >> "$temp_file_path"
        cat "$file_path" >> "$temp_file_path"
        echo -e "$breadcrumbs_bottom" >> "$temp_file_path"

        # Replace the original file with the modified temporary file
        mv "$temp_file_path" "$file_path"
    done

    echo -e "\n" >> "$index_file"  # New line for the next book
done

echo "All books processed into Markdown files for Obsidian import."