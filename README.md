# Snakemake pipeline for basic repeat masking

Pipeline, taking a set of unmasked genomes and for each creating a soft- and hard-masked version.

## Dependencies

The pipeline uses a `conda` environment specified in `envs/repeat_masking.yml`

To set up the environment run (ore use `mamba` for a faster set-up):

```sh
conda env create -f envs/repeat_masking.yml
```

## Running the pipeline

```sh
snakemake -p -j 1 --use-conda
```

## Details

Translation of the pipeline steps into `bash` for a single reference genome (`${SPEC}.fa.gz`)

```sh
SPEC="spec_1"
```

Starting by creating a database for the `RepeatModeler` step.

```sh
mkdir -p data/${SPEC}_mod/
BuildDatabase \
  -name data/${SPEC}_mod/${SPEC}_db \
  -engine ncbi data/${SPEC}.fa.gz
```

Modeling repeat families

```sh
cd data/${SPEC}_mod/
RepeatModeler \
  -engine ncbi \
  -pa 12 \
  -database ${SPEC}_db
mv RM_* ${SPEC}_model
```

Use the modeled repeat families to create a *soft* masked version of the reference genome (repeat sequence in the `fa` file in *lower case* - eg: `ATGCATgggccgggccgggccATGAT`)

```sh
RepeatMasker \
  -e rmblast \
  -pa 10 -s \
  -lib $data/${SPEC}_mod/{SPEC}_model/consensi.fa.classified \
  -xsmall ${SPEC}.fa.gz
mv data/${SPEC}.fa.masked data/${SPEC}_masked.fa
gzip data/${SPEC}_masked.fa
```
Convert the soft masked reference genome into a hard masked (lower case characters are converted to `N`, eg `ATGCATNNNNNNNNNNNNNNNATGAT`)

```sh
zcat data/${SPEC}_masked.fa.gz | \
  sed '/[>*]/!s/[atgcn]/N/g' | \
  gzip > data/${SPEC}_hardmasked.fa.gz
```

Finally, three versions of the reference:

```
data/
├── ...
├── spec_1.fa.gz
├── spec_1_masked.fa.gz
└── spec_1_hardmasked.fa.gz
```