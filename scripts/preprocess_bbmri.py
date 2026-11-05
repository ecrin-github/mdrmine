import pandas as pd
import re


def keep_id_only(url):
    if url and not pd.isna(url):
        x = re.search("\/([^\/]+)$", url)
        return x.group(1)
    return ""


def keep_sample_types(desc):
    if desc and not pd.isna(desc):
        x = re.search("Sample Types:\s+([^\.]+)", desc)
        if x:
            return x.group(1)
    return ""


def get_primary_id(dict, id):
    if dict and id and not pd.isna(id):
        if id in dict:
            return dict[id]
    return None


def construct_id_dict(id_fp):
    id_map = {}
    
    with open(id_fp, "r") as f:
        for line in f:
            separated = line.split("\t")
            if len(separated) == 2:
                primary_id = separated[0]
                for id in separated[1].split(","):
                    if id.endswith("\n"):
                        id = id[:-1]
                    id_map[id] = primary_id
            else:
                print("Unexpected ID file line length")
        
    return id_map

def main(main_dataset_fp, desc_fp, title_fp, id_fp, output):
    print("Reading CSV files")
    main_df = pd.read_csv(main_dataset_fp, dtype=str)
    desc_df = pd.read_csv(desc_fp, dtype=str)
    title_df = pd.read_csv(title_fp, dtype=str)

    print("Constructing dataset")
    # Pick fields
    main_df = main_df[["sd_oid", "sd_sid", "display_title", "access_url"]]
    main_df = pd.merge(main_df, desc_df, how="left", on="sd_oid")
    
    title_df = title_df[["sd_oid", "title_type_id", "title_text"]]
    # Filtering out constructed titles
    title_df = title_df.loc[title_df['title_type_id'] == "28"]

    main_df = pd.merge(main_df, title_df, how="left", on="sd_oid")

    # Fix URL
    main_df['access_url'] = main_df['access_url'].apply(keep_id_only)
    main_df["bbmri_id"] = main_df['access_url']
    main_df['access_url'] = main_df['access_url'].apply(lambda x: "https://directory.bbmri-eric.eu/ERIC/directory/#/collection/" + x)
    
    # Get material types
    main_df['display_title'] = main_df['display_title'].apply(keep_sample_types)
    
    main_df = main_df[["sd_sid", "bbmri_id", "title_text", "access_url", "display_title", "description text"]]
    main_df = main_df.rename(columns={'sd_sid': 'study_id', 'title_text': 'title', "access_url": "url", "display_title": "material_types", "description text": "description"})

    print("Setting study ID field based on ID resolver file (using primary ID)")
    id_map = construct_id_dict(id_fp)
    main_df['study_id'] = main_df['study_id'].apply(lambda x: get_primary_id(id_map, x))
    
    len_before = len(main_df)
    main_df = main_df.drop(main_df[main_df['study_id'] == None].index)
    len_after = len(main_df)
    
    print(f"Dropped {len_before-len_after} rows with unknown clinical trial IDs")

    print("Writing to file")
    main_df.to_csv(output, index=False)



if __name__ == "__main__":
    main_dataset_fp = "/home/ubuntu/data/bbmri/20230903_data_objects.csv"
    desc_fp = "/home/ubuntu/data/bbmri/20230903_object_descriptions.csv"
    title_fp = "/home/ubuntu/data/bbmri/20230903_object_titles.csv"
    id_fp = "/home/ubuntu/data/idfile/clinicaltrial"
    output = "/home/ubuntu/data/bbmri/cleaned.csv"
    
    main(main_dataset_fp, desc_fp, title_fp, id_fp, output)