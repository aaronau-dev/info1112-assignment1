#!/bin/bash
if [ "$#" -eq 0 ]
then
  echo "usage: no argument is provided"
  exit 1
fi

if [ "$#" -gt 1 ]
then
  echo "usage: more than one arguments are provided"
  exit 1
fi

if [ ! -f "$1" ]
then
  echo "usage: input is not a file or it does not exist"
  exit 1
fi

if [[ ! "$1" == *.vsc ]]
then
  echo "usage: input does not have the extension .vsc"
  exit 1
fi

if [ ! -s "$1" ]
then
  echo "usage: the file is empty – no .bin file is produced"
  exit 1
fi
bin_file="${1%.vsc}.bin"
> "$bin_file"

# read first line of .vsc file to see how many static values are there
first_line=$(head -n 1 "$1")
first_instruction=$((first_line + 2))
# read the second line - for quit, it is the instruction.
instruction_line=$(head -n $first_instruction "$1" | tail -n 1)
# searches through the text to find if ADD/SUB exist, or if it is purely QUIT
if grep -Eq '^(ADD|SUB),' "$1"
then
    echo "It is an ADD/SUB program"
else
    echo "It is a QUIT program"
fi

echo "The content of the .bin file is"
for ((i=2; i<$first_instruction; i++))
do
  value=$(head -n "$i" "$1" | tail -n 1)
  printf "%02x\n" "$value" | tee -a "$bin_file"
done
# take the contents of # and feed it into the read command with <<<
# in the read command, split the instruction by commas

total_lines=$(wc -l < "$1")
#echo "$total_lines" | cat -n "$1"
for ((j=$first_instruction; j<=total_lines; j++))
do
  instruction_line=$(head -n "$j" "$1" | tail -n 1)
  IFS="," read -r p1 p2 p3 <<< "$instruction_line"
  if [ $p1 == "LOAD" ]
  then
    opc=1
  fi

  if [ $p1 == "STORE" ]
  then
    opc=2
  fi

  if [ $p1 == "ADD" ]
  then
    opc=3
  fi

  if [ $p1 == "SUB" ]
  then
    opc=4
  fi

  if [ $p1 == "QUIT" ]
  then
    # set opcode 8 as per the spec
    opc=8
  fi

  if [ $p1 == "PRINT" ]
  then
    opc=9
  fi

    # p2, p3 map to register and address respectively
    reg=$p2
    address=$p3
    # as per the 16-bit instruction, move the field to its correct position
    # we shift it as it will just be '8' in 16 bit represention otherwise, instead of our specific format from spec

    : '
    - opcode shifted 10 bits to the left
    - register shifted 8 bits to the left
    - memory address does not require shift
    '
    final=$(($opc << 10 | $reg << 8 | $address))
    # 8 bits = 1 byte, so store them into two bytes.
    # shift the full 16-bit instruction and shift it right 8 places for first byte
    first_byte=$(($final >> 8))
    # keep the last 8 bits of final
    second_byte=$((final & 255))
    printf "%02x\n" "$first_byte" | tee -a "$bin_file"
    printf "%02x\n" "$second_byte" | tee -a "$bin_file"
done

