import argparse
import csv
from pathlib import Path


def sync_csv_by_first_column(file_a: str, file_b: str, has_header: bool = True) -> None:
    path_a = Path(file_a)
    path_b = Path(file_b)

    existing_keys = set()

    # 1. Read existing first-column keys from file B (if it already exists)
    if path_b.exists() and path_b.stat().st_size > 0:
        with path_b.open("r", newline="", encoding="utf-8") as f_b:
            reader_b = csv.reader(f_b)
            if has_header:
                next(reader_b, None)
            for row in reader_b:
                if row:
                    existing_keys.add(row[0].strip())

    rows_to_append = []

    # 2. Read file A and keep only rows whose first field is not in B
    with path_a.open("r", newline="", encoding="utf-8") as f_a:
        reader_a = csv.reader(f_a)
        header_a = next(reader_a, None) if has_header else None

        for row in reader_a:
            if not row:
                continue
            key = row[0].strip()
            if key not in existing_keys:
                rows_to_append.append(row)
                existing_keys.add(key)

    # 3. Append non-duplicate rows to file B
    write_header_to_new_file = (
        has_header
        and (not path_b.exists() or path_b.stat().st_size == 0)
        and header_a is not None
    )

    with path_b.open("a", newline="", encoding="utf-8") as f_b:
        writer_b = csv.writer(f_b)
        if write_header_to_new_file:
            writer_b.writerow(header_a)
        writer_b.writerows(rows_to_append)

    print(f"Appended {len(rows_to_append)} new row(s) from '{path_a}' to '{path_b}'.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deduplicate rows from file_a against file_b by first column and append new rows to file_b."
    )
    parser.add_argument("file_a", help="Source CSV file to read new rows from")
    parser.add_argument("file_b", help="Target CSV file to compare against and append to")
    parser.add_argument(
        "--no-header",
        action="store_true",
        help="Set if the CSV files do not have a header row",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    sync_csv_by_first_column(
        file_a=args.file_a,
        file_b=args.file_b,
        has_header=not args.no_header,
    )
