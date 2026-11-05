import os

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



def main(id_file_dir, curr_id_fn, new_id_fn):
    curr_primary_ids = set()
    new_primary_ids = set()
    
    with open(os.path.join(id_file_dir, curr_id_fn), "r") as cf:
        line = cf.readline()
        while line != "":
            curr_primary_ids.add(line.split("\t")[0])
            line = cf.readline()
        print(f"Read {len(curr_primary_ids)} primary IDs from the current ID file ({curr_id_fn})")
    
    with open(os.path.join(id_file_dir, new_id_fn), "r") as nf:
        line = nf.readline()
        while line != "":
            new_primary_ids.add(line.split("\t")[0])
            line = nf.readline()
        print(f"Read {len(new_primary_ids)} primary IDs from the new ID file ({new_id_fn})")

    new_diff = new_primary_ids - curr_primary_ids
    print(f"The new ID file contains {len(new_diff)} new primary ID{'s' if len(new_diff) != 1 else ''}.")

    diff = curr_primary_ids - new_primary_ids
    if len(diff) == 0:
        print("All primary IDs from the current ID file are still primary IDs in the new ID file.")
    else:
        print(f"{len(diff)} primary ID{'s' if len(diff) != 1 else ''} from the current ID file are missing as primary identifiers in the new ID file:")
        for id in diff:
            print(id)



if __name__ == "__main__":
    id_file_dir = "/home/ubuntu/data/idfile"
    current_id_filename = "clinicaltrial"
    new_id_filename = "20261105_125410_id_file.tsv"
    
    main(id_file_dir, current_id_filename, new_id_filename)