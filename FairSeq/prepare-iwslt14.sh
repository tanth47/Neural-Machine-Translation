#!/usr/bin/env bash
#
# Adapted from https://github.com/facebookresearch/MIXER/blob/master/prepareData.sh

echo 'Cloning Moses github repository (for tokenization scripts)...'
git clone https://github.com/moses-smt/mosesdecoder.git

echo 'Cloning Subword NMT repository (for BPE pre-processing)...'
git clone https://github.com/rsennrich/subword-nmt.git

SCRIPTS=mosesdecoder/scripts
TOKENIZER=$SCRIPTS/tokenizer/tokenizer.perl
LC=$SCRIPTS/tokenizer/lowercase.perl
CLEAN=$SCRIPTS/training/clean-corpus-n.perl
BPEROOT=subword-nmt/subword_nmt
BPE_TOKENS=10000

src=en
tgt=vi
lang=en-vi
prep=iwslt.tokenized.en-vi
tmp=$prep/tmp
orig=/content/KC4.0_MultilingualNMT/data/iwslt_en_vi

mkdir -p $tmp $prep

echo "pre-processing train data..."
for l in $src $tgt; do
    f=train.$l
    tok=train.tok.$l

    cat $orig/$f | perl $TOKENIZER -threads 8 -l $l > $tmp/$tok
    echo ""
done

perl $CLEAN -ratio 1.5 $tmp/train.tok $src $tgt $tmp/train.clean 1 175
for l in $src $tgt; do
    perl $LC < $tmp/train.clean.$l > $tmp/train.$l
done

echo "pre-processing valid/test data..."
for l in $src $tgt; do
    for o in $(ls $orig/tst*.$l); do
        fname=${o##*/}
        f=$tmp/$fname
        echo $o $f
        cat $o | perl $TOKENIZER -threads 8 -l $l | perl $LC > $f
        echo ""
    done
done

echo "creating train, valid, test..."
for l in $src $tgt; do
    mv $tmp/tst2012.$l $tmp/valid.$l
    mv $tmp/tst2013.$l $tmp/test.$l
done

TRAIN=$tmp/train.en-vi
BPE_CODE=$prep/code
rm -f $TRAIN
for l in $src $tgt; do
    cat $tmp/train.$l >> $TRAIN
done

echo "learn_bpe.py on ${TRAIN}..."
python $BPEROOT/learn_bpe.py -s $BPE_TOKENS < $TRAIN > $BPE_CODE

for L in $src $tgt; do
    for f in train.$L valid.$L test.$L; do
        echo "apply_bpe.py to ${f}..."
        python $BPEROOT/apply_bpe.py -c $BPE_CODE < $tmp/$f > $prep/$f
    done
done
