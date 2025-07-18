#!/bin/bash
SRR_IDS=(SRR8400805 SRR8400806 SRR8400807 SRR8400808)

# Step 1: Setup directories and 
# Set the main directory using .research_config
# Extract the path to LOCAL_TIAN_2019_RAW_DATA_DIR from .research_config
MAIN_DIR=$(source ~/.research_config; echo $LOCAL_TIAN_2019_RAW_DATA_DIR)
mkdir -p "$MAIN_DIR"

# Check if MAIN_DIR is set
if [ -z "$MAIN_DIR" ]; then
  echo "Error: MAIN_DIR is not set. Check .research_config file."
  exit 1
fi

# Raw directory
RAW_DIR="${MAIN_DIR}raw/"
mkdir -p "$RAW_DIR"

# Processed directory
PROCESSED_DIR="${MAIN_DIR}processed/"
mkdir -p "$PROCESSED_DIR"

# SCRACTH directory
FASTQ_DIR=$SCRATCH_DIR/Tian_2024/
mkdir -p "$FASTQ_DIR"

# Check if prefetch tools are installed
if ! command -v prefetch &> /dev/null || ! command -v fastq-dump &> /dev/null; then
  echo "Error: prefetch or fastq-dump not found. Ensure SRA Toolkit is installed."
  exit 1
fi

# Check if Cell Ranger is installed
if ! command -v cellranger &> /dev/null; then
  echo "Error: cellranger command not found."
  exit 1
fi

# Step 2: Download and extract the GRCh38 transcriptome database
cd "$RAW_DIR" || exit
if [ -d "refdata-gex-GRCh38-2020-A" ]; then
  echo "Directory already exists, skipping download and extraction."
else
  if [ ! -f "refdata-gex-GRCh38-2020-A.tar.gz" ]; then
    wget https://cf.10xgenomics.com/supp/cell-exp/refdata-gex-GRCh38-2020-A.tar.gz
  fi
  tar -zxvf refdata-gex-GRCh38-2020-A.tar.gz
fi
REFDATA_DIR="${RAW_DIR}refdata-gex-GRCh38-2020-A/"

# Step 3: Dump SRR files into FASTQ format (split mode) and ensure target directories exist
for SRR_ID in "${SRR_IDS[@]}"; do

  # Dump SRR files into FASTQ format
  if [ -d "$RAW_DIR$SRR_ID" ]; then
    echo "Skipping Downloading $SRR_ID (folder exists)"
  else
    echo "\n=== Processing ${SRR_ID} ==="
    cd "$RAW_DIR" || exit
    prefetch $SRR_ID
    fastq-dump --split-files "$RAW_DIR$SRR_ID" -O "$FASTQ_DIR$SRR_ID"
    echo "${SRR_ID} Downloaded"
  fi

  # Run cellranger if necessary
  if [ -d "$PROCESSED_DIR/$SRR_ID/outs" ]; then
    echo "Skipping Processing $SRR_ID (folder exists)"
  else
  
    # Rename FASTQ files to enable cellranger count
    cd "$FASTQ_DIR$SRR_ID" || exit
    if [ -f "${SRR_ID}_1.fastq" ]; then
      mv "${SRR_ID}_1.fastq" "${SRR_ID}_S1_L001_R1_001.fastq"
    else
      echo "Warning: ${SRR_ID}_1.fastq not found!"
    fi
    if [ -f "${SRR_ID}_2.fastq" ]; then
      mv "${SRR_ID}_2.fastq" "${SRR_ID}_S1_L001_R2_001.fastq"
    else
      echo "Warning: ${SRR_ID}_2.fastq not found!"
    fi
    if [ -f "${SRR_ID}_3.fastq" ]; then
      mv "${SRR_ID}_3.fastq" "${SRR_ID}_S1_L001_I1_001.fastq"
    else
      echo "Warning: ${SRR_ID}_3.fastq not found!"
    fi
    
    # set the directory to the PROCESSED_DIR
    cd "$PROCESSED_DIR" || exit
    cellranger count --id="${SRR_ID}" \
                    --transcriptome="$REFDATA_DIR" \
                    --fastqs="${FASTQ_DIR}${SRR_ID}" \
                    --sample="${SRR_ID}" \
                    --create-bam=false
  fi

  # Deleting fastq files to save space if download succeeds
  if [ -d "$PROCESSED_DIR$SRR_ID/outs" ]; then
    rm ${FASTQ_DIR}${SRR_ID}/*.fastq
    echo "${SRR_ID} processed"
  else
    echo "Cellranger failed for ${SRR_ID}"
    rm -r "${PROCESSED_DIR}${SRR_ID}"
  fi
done

echo "All tasks completed successfully!"
