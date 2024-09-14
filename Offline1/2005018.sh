#!/usr/bin/bash

usage() {
  echo "Usage: "$0" -i input.txt" 
  exit 1 
}

check_allowed_archs() {
  valid=("rar" "tar" "zip")
  read -r -a arch_arr <<< "$1"
  for i in "${arch_arr[@]}";
  do
    if [[ ! "${valid[@]}" =~ "$i" ]]; then
      echo "The format: "$i" is not supported."
      exit 1
    fi
  done
}

check_lang() {
  valid=("c" "cpp" "python" "sh")
  read -r -a given <<< "$1"
  for lang in "${given[@]}";
  do
    if [[ ! "${valid[@]}" =~ "$lang" ]]; then
      echo "The Language: "$lang" is not supported."
      exit 1
    fi
  done
}

check_file_lang() {
  valid=("c" "cpp" "sh" "python")
  read -r ext <<< "$1"
  # echo "$ext"
  if [[ ! "${valid[@]}" =~ "$ext" ]]; then
    echo "The language is not supported."
    return 1
  fi
}

check_ints() {
  re='^[0-9]+$'
  for i in "$@";
  do
    if [[ ! "$i" =~ $re ]]; then
      echo ""$i" is invalid as an integer."
      exit 1
    fi
  done
}



check_paths() {
  if [[ ! -d "$1" ]]; then
    echo "The directory "$1" does not exist."
    exit 1
  fi
  if [[ ! -f "$2" ]]; then
    echo "The file "$2" does not exist."
    exit 1
  fi
}


check_range() {
  re='^[0-9]+$'
  read -r strt end <<< "$1"
  if [[ ! "$strt" =~ $re || ! "$end" =~ $re ]]; then
    echo "ID must be valid integers."
    exit 1
  fi

  if [[ "$strt" -gt "$end" ]]; then
    echo "Starting ID must be less than or equal to ending ID."
    exit 1
  fi
}

check_file_ID() {
  filename="$1"
  ID="${filename%.*}"
  read -r strt end <<< "$2"
  re='^[0-9]+$'
  if [[ ! "$ID" =~ $re ]]; then
    echo "$filename not valid."
    mv "$3" "issues/"
    return 1
  fi
  if [[ "$ID" -lt "$strt" || "$ID" -gt "$end" ]]; then 
    echo "$filename not in range"
    mv "$3" "issues/"
    return 1
  fi
  return 0
}

marks_csv="marks.csv"

if [[ ! -f "$marks_csv" ]]; then
  echo "ID,marks,marks_deducted,total,remarks" > "$marks_csv"
fi

update_marks_csv() {
  ID="$1"
  deduc="$3"
  tot="$4"
  marks="$2"
  remarks="$5"
  if grep -q "^$ID", "$marks_csv"; then
    awk -F, -v _ID="$ID" -v _marks="$marks" -v _deduc="$deduc" -v _tot="$tot" -v _rem="$remarks" '
    BEGIN { OFS = FS }
    $1 == _ID {
      if (_marks != "NA") $2 = _marks;
      if (_deduc != "NA") {
        $2 -= _deduc;
        $3 += _deduc;
      }
      if (_tot != "NA") $4 = _tot;
      if (_rem != "NA") $5 = _rem;
    }
    { print }
    ' "$marks_csv" > temp.csv && mv temp.csv "$marks_csv"
  else
    [[ "$marks" == "NA" ]] && marks="N/A"
    [[ "$deduc" == "NA" ]] && deduc=0
    [[ "$tot" == "NA" ]] && tot=100
    [[ "$remarks" == "NA" ]] && remarks="None"

    echo "$ID,$marks,$deduc,$tot,$remarks" >> "$marks_csv"
  fi
}

init_csv() {
  read -r strt end <<< "$1" ##range
  tot="$2"
  for((id=strt;id<=end;id++));
  do
    if ! grep -q "^$id", "$marks_csv"; then
      echo "$id,$tot,0,$tot,Not graded" >> "$marks_csv"
    fi
  done
}


check_inside_folder() {
  Dir="$1"
  ID=$(basename $1)
  file_cnt=0
  for i in "$Dir"/*;
  do
    file_cnt=$((file_cnt+1))
  done
  if [[ "$file_cnt" -ne 1 ]]; then
    echo "Folder has multiple files."
    return 1
  fi
  for i in "$Dir"/*; 
  do
    curr_ID=$(basename $i)
    ext="${curr_ID##*.}"
    curr_ID="${curr_ID%.*}"
    if [[ "$ID" -ne "$curr_ID" ]]; then
      echo "A file has different ID."
      return 1
    fi
    if [[ "$ext" != "cpp" && "$ext" != "c" && "$ext" != "py" && "$ext" != "sh" ]]; then
      echo "File extension not valid."
      return 1
    fi
  done
  return 0
}


unzip_subs() {
  workingDir="$1"
  read -r strt end <<< "$2"
  arch="$3"
  tot="$4"
  penal_guide="$5"
  for i in "$workingDir"/*;
  do
    filename=$(basename $i)
    ext="${filename##*.}"
    ID="${filename%.*}"
    if [[ "$ID" == "expected_output" ]]; then
      continue
    fi
    re='^[0-9]+$'
    if [[ ! "$ID" =~ $re || "$ID" -lt "$strt" || "$ID" -gt "$end" ]]; then
      mv "$i" "issues/"
      continue
    fi
    if [[ "$arch" == "false" ]]; then 
      continue;
    fi
    if [[ -d "$i" ]]; then
      update_marks_csv "$ID" "NA" "$penal_guide" "NA" "Issue-1"
      continue
    fi
    if [[ "$ext" == "py" || "$ext" == "sh" || "$ext" == "cpp" || "$ext" == "c" ]]; then
      update_marks_csv "$ID" "0" "$tot" "NA" "Skipped eval. Wrong format submission."
      mv "$i" "issues/"
      continue;
    fi
    if [[ "$ext" == "zip" ]]; then
      # unzip "$i" -d "$workingDir"
      (cd "$workingDir" && unzip "$filename")
    elif [[ "$ext" == "tar" ]]; then
      (cd "$workingDir" && tar -xvf "$filename")
    elif [[ "$ext" == "rar" ]]; then
      (cd "$workingDir" && unrar e "$filename")
    else
      ### means bad arch format but valid ID.WIll skip eval. will set remarks[ID] = "skipped"
      update_marks_csv "$ID" "0" "$tot" "NA" "Issue-2. Skipped eval"
      mv "$i" "issues/"
    fi
  done
}

RunCode() {
  Dir="$1"
  cd "$Dir"
  file=$(ls -1 | head -1)
  base="${file%.*}"
  ext="${file##*.}"
  if [[ "$ext" == "cpp" ]]; then
    g++ "$file" -o "${base}_exec"
    ./"${base}_exec" > "${base}_output.txt"
  elif [[ "$ext" == "py" ]]; then
    python3 "$file" >  "${base}_output.txt"
  elif [[ "$ext" == "sh" ]]; then
    bash "$file" > "${base}_output.txt"
  elif [[ "$ext" == "c" ]]; then
    gcc "$file" -o "${base}_exec"
    ./"${base}_exec" > "${base}_output.txt" 
  fi 
}

create_Dirs() {
  workingDir="$1"
  read -r strt end <<< "$2"
  tot="$3"
  for i in "${workingDir}"/*; 
  do
    filename=$(basename $i)
    ext="${filename##*.}"
    ID="${filename%.*}"
    if [[ -d "$i" ]]; then
      FolderDir="$i"
      check_inside_folder "$workingDir/$filename"
      if [[ "$?" -ne 0 ]]; then
        update_marks_csv "$ID" "0" "$tot" "$tot" "Skipped eval. Not a valid folder."
        mv "$FolderDir" "issues/"
      fi
      continue
    fi
    if [[ "$ext" == "txt" || "$ext" == "tar" || "$ext" == "zip" ||  "$ext" == "rar" ]]; then 
      continue
    fi
    check_file_lang "$ext"
    if [[ $? -ne 0 ]]; then
      update_marks_csv "$ID" "0" "$tot" "$tot" "Issue-3"
      mv "$i" "issues/"
      continue
    fi
    mkdir -p "$workingDir/$ID"
    mv "$i" "$workingDir/$ID/" 
  done
}


check_subs() {
  Dir="$1" 
  for i in "$Dir"/*; 
  do 
    filename=$(basename $i)
    ext="${filename##*.}"
    if [[ "$ext" == "tar" || "$ext" == "rar" || "$ext" == "zip" || "$ext" == "txt" ]]; then
      continue
    else 
      workingDir="$i"
      RunCode "$workingDir"
    fi
  done
  cd "$2"
}


macth_outputs() {
  Dir="$1"
  mapfile -t expected < "$Dir/expected_output.txt"
  for folder in "$Dir"/*;
  do
    if [[ -d "$folder" ]]; then
      filename=$(basename $folder)
      ID="${filename%.*}"
      outputfile="$Dir/$filename/${filename}_output.txt"
      mapfile -t output < "$outputfile"
      compare "$expected" "$output" "$ID" "$2"
    fi
  done
}

compare() {
  expected="$1"
  output="$2"
  ID="$3"
  penal_match="$4"
  err=0
  for((i=0;i<"${#expected[@]}";++i));do
    if [[ "${expected[$i]}" != "${output[$i]}" ]]; then
      ((err++))
    fi
  done
  ((penal_match *= err ))
  if [[ err -gt 0 ]]; then
    update_marks_csv "$ID" "NA" "$penal_match" "NA" "NA"
  fi
}

finalize() {
  read -r strt end <<< "$2"
  for((i=strt;i <= end; ++i)); do
    echo "$i"
  done
}


if [[ ! $# -eq 2 ]]; then
  usage
fi


if [[ ! -f "$2" ]]; then 
    echo "The file does not exist."
    usage
fi

line_cnt=11

file_line_cnt=$(cat "$2" | wc -l)

# echo "$file_line_cnt"
if [[ "$line_cnt" -ne "$file_line_cnt" ]]; then
  echo "Sorry, number of lines does not match expected line count."
  usage
fi


{
  read -r arch
  read -r arch_frmt
  read -r lang
  read -r tot
  read -r penal_match
  read -r dir
  read -r range
  read -r correct_output
  read -r penal_guide ## this is for violating submission guidelines.
  read -r plag
  read -r penal_plag
} < "$2" 

# echo "$penal_plag"


if [[ "$arch" != "true" && "$arch" != "false" ]]; then
  echo "Archive not in correct format"
  exit 1
fi

check_allowed_archs "$arch_frmt"

check_ints "$tot" "$penal_guide" "$penal_plag" "$penal_match" 

check_paths "$dir" "$correct_output"

check_lang "$lang"

check_range "$range"

declare -A remarks
declare -A marks
declare -A deduc


if [[ ! -d "issues" ]]; then
  mkdir -p "issues"
fi

if [[ ! -d "checked" ]]; then
  mkdir -p "checked"
fi

init_csv "$range" "$tot"

unzip_subs "$dir" "$range" "$arch" "$tot" "$penal_guide"

create_Dirs "$dir" "$range" "$tot"

curr=$(pwd)

check_subs "$dir" "$curr"

macth_outputs "$dir" "$penal_match"

finalize "$dir" "$range"




# /mnt/d/OS/Offline1/Assignment


