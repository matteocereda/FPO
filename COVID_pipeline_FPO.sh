# COVID to dos ======
# NB Read all before starting ===========

# --------------------------------------------------------------------
#  PERALTA LOGIN
# --------------------------------------------------------------------
# ssh peralta e aprire una sessione interattiva
ssh giorgio.giardina@172.27.0.60
# attivare sempre una sesione interattiva nel gestore di code.
# ***!!!NON lavorare sul front-end PERALTA***
qsub -I -q interactive -l ncpus=14

# --------------------------------------------------------------------
# 0. Al primo accesso, creare un ambiente pangolin nella propria home

cd
git clone https://github.com/cov-lineages/pangolin.git
cd pangolin
conda env create -f environment.yml
conda activate pangolin
pip install .

# --------------------------------------------------------------------
#  PROCESSING DATA
# --------------------------------------------------------------------
# 0. Inizio procedura di analisi

RUN_FOLDER='/hpcnfs/techunits/seq-fpo/'
RUN='NOME_DELLA_RUN'
# 210325_M02679_0214_000000000-JLFNL

#specificare l'utente che fa l'analisi
USER="giorgio.giardina" 

cd ${RUN_FOLDER}/${RUN}

# --------------------------------------------------------------------
# 1. Se sequenziamento NextSeq500 ==> FARE demultiplexing. 
# Necessario avere nella cartella della run il 
# file SampleSheet.csv fornito dai biologi

conda activate default
# Qualora conda non si attivasse lanciare il comando:
# source /hpcnfs/software/anaconda/anaconda3/etc/profile.d/conda.sh

/hpcnfs/software/bcl2fastq2/bin/bcl2fastq --barcode-mismatches 1 -p $NCPUS -r $NCPUS -w $NCPUS --no-lane-splitting  > bcl2fastq.log 2>&1

conda deactivate

# --------------------------------------------------------------------
# 2. entrare nella cartella dei fastq files
cd Data/Intensities/BaseCalls

# --------------------------------------------------------------------
# 3. Cambiare il filename dei fastq.gz files  

# 3.A. Nel caso di sequenziamento MiSeq 

for i in 1*fastq.gz; 
do 
 echo $i;
 arrIN=(${i//_/ });
 barcode=$(printf '%s.%s.fastq.gz' "${arrIN[0]}" "${arrIN[3]}");
 mv $i $barcode;
done;


# 3.B. Nel caso di sequenziamento NextSeq 

for i in 1*fastq.gz; 
do 
 echo $i;
 arrIN=(${i//_/ });
 barcode=$(printf '%s.%s.fastq.gz' "${arrIN[0]}" "${arrIN[2]}");
 mv $i $barcode;
done

# qualora non siate sicuri del codice provate con 'echo' al posto di 'mv'



# --------------------------------------------------------------------
# 4. I campioni posso essere corsi a blocchi di 50 alla volta.
# se il numero e' superiore a 50 è necessario splittare i campioni
# Controllare il numero di campioni

ll 1*R1* | wc -l

# Decidere quanti gruppi fare tenendo conto del massimo di 50
# Creare per ogni gruppo una cartella apposita in cui fare i link simbolici ai fastq
# Supponendo di avere 100 campioni

mkdir GROUP1
mkdir GROUP2
# ... mkdir GROUPN

path="${RUN_FOLDER}${RUN}/Data/Intensities/BaseCalls/"

lista=($(ls ${path}*.R1.fastq.gz))

GROUP=GROUP1
for i in {0..49};  # nb... il primo campione è 0
do
f=${lista[$i]};
j=$(basename $f);
echo $j;
arrIN=(${j//./ });
sample="${arrIN[0]}";
echo $sample;
ln -s ${path}${sample}* $GROUP;
done;


GROUP=GROUP2
for i in {50..99};
do
f=${lista[$i]};
j=$(basename $f);
echo $j;
arrIN=(${j//./ });
sample="${arrIN[0]}";
echo $sample;
ln -s ${path}${sample}* $GROUP;
done;

# NB cambiare i valori nei cicli in modo da fare in modo che tutti i campioni siano presenti
# In caso ci siano meno di 50 campioni tenere comunque la procedura e creare una unica cartella GROUP1

# --------------------------------------------------------------------
# 5. mettersi nella WORKING directory

cd /hpcnfs/data/fpo

# --------------------------------------------------------------------
# 6.  Per ogni gruppo di campioni è necessario creare una apposita cartella e un apposito codice. 

GROUP=GROUP1

WORKDIR="/hpcnfs/data/fpo/${RUN}_${GROUP}"
OUTNAME="${RUN}_${GROUP}"
name="${RUN}_${GROUP}"

if [ -e "${WORKDIR}" ]; then echo "Folder present"; else mkdir -p "${WORKDIR}"; fi
if [ -e "${WORKDIR}/logs" ]; then echo "Folder logs present"; else mkdir -p "${WORKDIR}/logs"; fi
if [ -e "${WORKDIR}/runs" ]; then echo "Folder runs present"; else mkdir -p "${WORKDIR}/runs"; fi

cd $WORKDIR

cat <<EOT > "${WORKDIR}/runs/${name}.sh"
#PBS -q workq -j oe -l select=1:ncpus=28:mem=250Gb -N $name -o $WORKDIR/logs/$name
cd $WORKDIR
SCRIPT=/hpcnfs/data/fpo/nfcore_viralrecon_pangolin.sh
\$SCRIPT $WORKDIR $OUTNAME "250.GB"
EOT

cd ..

# ****RIPETERE con tutti i GRUPPI di campioni**** 


# --------------------------------------------------------------------
# 7. Per ciascuna cartella creata è necessario creare un "samplesheet.csv" 

GROUP=GROUP1
cd "/hpcnfs/data/fpo/${RUN}_${GROUP}"
echo "sample,fastq_1,fastq_2" > samplesheet.csv

path="${RUN_FOLDER}/${RUN}/Data/Intensities/BaseCalls/${GROUP}/" 

for i in $(ls ${path}*.R1.fastq.gz);
do
j=$(basename $i);
echo $j;
arrIN=(${j//./ });
echo "${arrIN[0]}";
sample=${arrIN[0]}; 
i_m=${path}${sample}.R2.fastq.gz
printf  "%s\n" "${sample},${i},${i_m}" >> samplesheet.csv;
done;

cd ..

# ****RIPETERE con tutti i GRUPPI di campioni**** 

# --------------------------------------------------------------------
# 8. Ritornare nella cartella di analisi e sottomettere l'analisi al
# gestore di code.

GROUP=GROUP1
name="${RUN}_${GROUP}"
cd "/hpcnfs/data/fpo/${RUN}_${GROUP}"
qsub runs/${name}.sh

cd ..

# ****ripetere con tutti i GRUPPI di campioni**** 

# --------------------------------------------------------------------
# 9. terminare la sessione interattiva del gestore di code
exit

# --------------------------------------------------------------------
# 10. Controllare il proseguimento del job con il comando

qstat -as1 -u $USER

# --------------------------------------------------------------------
# 10. Quando il job risulta terminato entrare nella cartella di analisi 
# e controllare che ci sia il file *lineage_report.csv

# ----------------------------------------------------------------------
# 11. Riunire i risultati di tutte le analisi in un unico file

qsub -I -q interactive -l ncpus=1

cd /hpcnfs/data/fpo

RUN='NOME_DELLA_RUN'
# 210325_M02679_0214_000000000-JLFNL

analysis_folder="/hpcnfs/data/fpo/${RUN}*" 

conda activate default

# Se erano stati creati più gruppi il ${RUN}_all.lineage_report.csv conterrà più di un header
# per cui bisogna eliminare quelli che risultano
# interni al testo, lasciando solo quello nella prima riga

sed -n 1p ${analysis_folder}/*.lineage_report.csv > ${RUN}_all.lineage_report.csv
parallel sed 1d ::: ${analysis_folder}/*.lineage_report.csv >> ${RUN}_all.lineage_report.csv

cat ${analysis_folder}/variants/ivar/consensus/${RUN}*fa > ${RUN}_all.fa

conda deactivate

exit

# --------------------------------------------------------------------
# PS
# --------------------------------------------------------------------
# In caso non ci fosse il file *lineage_report.csv controllare lo stato 
# di pangolin con il seguente comando dopo aver attivato una sessione
# interattiva nel gestore di code

qsub -I -q interactive -l ncpus=1
pangolin --update

# seguire le indicazioni suggerite dal comando



