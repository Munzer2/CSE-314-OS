#!/usr/bin/bash

# ProcessInp() {
#     echo "Parameter #1 is $1"
# }


# values=()

# while read -r line; 
# do
#     values+=("$line")
# done < sample.txt


# for i in "${!values[@]}"; do
#   echo "Line $((i+1)): ${values[$i]}"
# done

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
    exit 1
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
    exit 1
  fi
  if [[ "$ID" -lt "$strt" || "$ID" -gt "$end" ]]; then 
    echo "$filename not in range"
    exit 1
  fi
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
    exit 1
  fi
  for i in "$Dir"/*; 
  do
    curr_ID=$(basename $i)
    curr_ID="${curr_ID%.*}"
    if [[ "$ID" -ne "$curr_ID" ]]; then
      echo "A file has different ID."
      exit 1
    fi
  done
}


unzip_subs() {
  workingDir="$1"
  for i in "$workingDir"/*;
  do
    filename=$(basename $i)
    ext="${filename##*.}"
    if [[ "$ext" == "zip" ]]; then
      # unzip "$i" -d "$workingDir"
      (cd "$workingDir" && unzip "$filename")
    elif [[ "$ext" == "tar" ]]; then
      (cd "$workingDir" && tar -xvf "$filename")
    elif [[ "$ext" == "rar" ]]; then
      (cd "$workingDir" && unrar e "$filename")
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
  for i in "${workingDir}"/*; 
  do
    filename=$(basename $i)
    if [[ -d "$i" ]]; then
      check_file_ID "$filename" "$2"
      check_inside_folder "$workingDir/$filename"
      continue
    fi
    ext="${filename##*.}"
    ID="${filename%.*}"
    if [[ "$ext" == "txt" || "$ext" == "tar" || "$ext" == "zip" ||  "$ext" == "rar" ]]; then 
      continue
    fi
    check_file_lang "$ext"
    check_file_ID "$filename" "$2"
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
    # elif [[ "$ext" == "c" ]]; then
    #   echo "This is a c file."
    #   basename="${filename%.c}"
    #   outputfile="$workingDir/$basename"
    #   gcc "$i" -o "$outputfile"
    #   (cd "$workingDir" && ./"$basename" > "${basename}_output.txt")
    else 
      workingDir="$i"
      RunCode "$workingDir"
    fi
  done
  cd "$2"
}

helper() { 
  for i in "$1"/*; 
  do
    if [[ -d "$i" ]]; then
      for j in "$i"/*;
      do
        file=$(basename $j)
        ext="${file##.*}"
        if [[ "$ext" == "txt" || "$ext" == "$file" ]]; then
          echo "$j"
        fi
      done
    fi
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

unzip_subs "$dir"

create_Dirs "$dir" "$range"

curr=$(pwd)

check_subs "$dir" "$curr"

helper "$dir"

ls -a

