#!/usr/bin/env python3
"""
Test script for PDF extraction improvements
"""
import os
import sys
sys.path.append('.')

from app.ingest import extract_text_from_pdf, clean_extracted_text

def test_pdf_extraction(file_path):
    """Test the improved PDF extraction function"""
    if not os.path.exists(file_path):
        print(f"ERROR: File not found: {file_path}")
        return

    print("=" * 60)
    print(f"Testing PDF extraction for: {file_path}")
    print("=" * 60)

    try:
        # Extract text using our improved function
        extracted_text = extract_text_from_pdf(file_path)

        print(f"\nExtraction Results:")
        print(f"- Total characters: {len(extracted_text)}")
        print(f"- Total words: {len(extracted_text.split())}")
        print(f"- Total lines: {len(extracted_text.split('\n'))}")

        print(f"\nFirst 1000 characters of extracted text:")
        print("-" * 40)
        print(extracted_text[:1000])
        print("-" * 40)

        if len(extracted_text) < 100:
            print("⚠️  WARNING: Very little text extracted! This suggests extraction issues.")
        else:
            print("✅ Extraction appears successful!")

        # Look for specific content that should be in the competency document
        key_phrases = [
            "Flow 1", "Flow 2", "Flow 3",
            "competency management",
            "employee addition",
            "tracking competency",
            "Beginner", "Expert",
            "Technical", "Functional", "Adaptive"
        ]

        found_phrases = []
        for phrase in key_phrases:
            if phrase.lower() in extracted_text.lower():
                found_phrases.append(phrase)

        print(f"\nKey phrases found ({len(found_phrases)}/{len(key_phrases)}):")
        for phrase in found_phrases:
            print(f"  ✅ {phrase}")

        if len(found_phrases) < len(key_phrases) * 0.5:
            print("⚠️  WARNING: Many expected phrases not found. Extraction may be incomplete.")

    except Exception as e:
        print(f"ERROR during extraction: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    # Test with a sample PDF if available
    test_files = [
        "./temp/Competencies Management.pdf",
        "./test.pdf",
        "Competencies Management.pdf"
    ]

    for test_file in test_files:
        if os.path.exists(test_file):
            test_pdf_extraction(test_file)
            break
    else:
        print("No test PDF files found. Please provide a PDF file to test.")
