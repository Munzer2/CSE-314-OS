for i in "$1"/*; 
  do
    if [[ -d "$i" ]]; then
      for j in "$i"/*;
      do
        file=$(basename $j)
        ext="${file##*.}"
        if [[ "$ext" == "txt" || "$ext" == "$file" ]]; then
          # echo "$j"
          rm "$j"
        fi
      done
    fi
  done