'''
snakemake -p -j 1 --use-conda
'''
import os

configfile: "config.yml"

SPECS = config[ 'genomes' ]

rule all:
    input: expand("data/{spec}_hardmasked.fa.gz", spec = SPECS )

rule build_db:
    input: 'data/{spec}.fa.gz'
    output: touch("data/waypoints/db_{spec}.done")
    log:
      'logs/db/{spec}.log'
    conda: 'repeat_masking'
    shell:
      """
      mkdir -p data/{wildcards.spec}_mod/ 
      BuildDatabase -name data/{wildcards.spec}_mod/{wildcards.spec}_db -engine ncbi data/{wildcards.spec}.fa.gz 2>{log}
      """

rule model_repeats:
    input:
      db_done = "data/waypoints/db_{spec}.done"
    output:
      directory("data/{spec}_mod/{spec}_model")
    params:
      wd = os.getcwd()
    log:
      'logs/mod/{spec}.log'
    conda: 'repeat_masking'
    threads: 8
    shell:
      """
      cd data/{wildcards.spec}_mod/
      RepeatModeler -engine ncbi -pa {threads} -database {wildcards.spec}_db >& {params.wd}/{log}
      mv RM_* {wildcards.spec}_model
      """

rule mask_repeats:
    input: 
      model = "data/{spec}_mod/{spec}_model",
      unmasked_genome = 'data/{spec}.fa.gz'
    output: 'data/{spec}_masked.fa.gz'
    log:
      'logs/mask/{spec}.log'
    conda: 'repeat_masking'
    threads: 8
    shell:
      """
      RepeatMasker \
        -e rmblast \
        -pa {threads} -s \
        -lib {input.model}/consensi.fa.classified \
        -xsmall {input.unmasked_genome} 2> {log}
      mv data/{wildcards.spec}.fa.masked data/{wildcards.spec}_masked.fa
      gzip data/{wildcards.spec}_masked.fa
      """

rule convert_to_hardmasked:
    input: 'data/{spec}_masked.fa.gz'
    output: 'data/{spec}_hardmasked.fa.gz'
    shell:
      """
      zcat {input}| sed '/[>*]/!s/[atgcn]/N/g' | gzip > {output}
      """