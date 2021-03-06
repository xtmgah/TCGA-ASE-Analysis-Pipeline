#!/usr/bin/perl -w

use MCE::Map;
use FindBin qw($Bin);
use lib "$Bin/..";
use Imputation_Plink;
use Parsing_Routines;
use Cwd 'realpath';
use Cwd;
use Getopt::Long;
use strict;

my $time = localtime;
print "Script started on $time.\n";

#Changes to the directory of the script executing;
chdir $Bin;

my $impute_plink = TCGA_Lib::Imputation_Plink->new;
my $parsing = TCGA_Lib::Parsing_Routines->new;
my $TCGA_Pipeline_Dir = realpath("../../");

GetOptions(
    'disease|d=s' => \my $disease_abbr,#e.g. OV
    'help|h' => \my $help
) or die "Incorrect options!\n",$parsing->usage;

if($help)
{
    $parsing->usage;
}

if(!defined $disease_abbr)
{
    print "disease type was not entered!\n";
    $parsing->usage;
}

my $database_path = "$TCGA_Pipeline_Dir/Database";

#Check if there is no Database directory
if(!(-d "$database_path"))
{
    print STDERR "$database_path does not exist. It was either moved, renames, deleted or has not been downloaded.\nPlease check the README.md file on the github page to find out where to get the Database directory.\n";
    exit;
}

my $Analysispath = realpath("../../Analysis");

#Checks if there is no Analysis directory
if (!(-d "$Analysispath"))
{
    print STDERR "$Analysispath does not exist. It was either deleted, moved or renamed.\n";
    print STDERR "Please run script 0_Download_SNPArray_From_GDC.pl.\n";
    exit;
}
elsif(!(-d "$Analysispath/$disease_abbr"))
{
    print STDERR "$Analysispath/$disease_abbr does not exist. It was either deleted, moved or renamed.\n";
    print STDERR "Please run script 0_Download_SNPArray_From_GDC.pl.\n";
    exit;
}

my $RNA_Path = "$Analysispath/$disease_abbr/RNA_Seq_Analysis";

if (!(-d $RNA_Path))
{
    print STDERR "$RNA_Path does not exist. Either it was deleted, moved or renamed.\n";
    print STDERR "Please run script 1.0_Prep_SNPs_for_Imputation_and_Plink.pl.\n";
    exit;
}

if(!(-d "$RNA_Path/peds") or !(-d "$RNA_Path/maps"))
{
    print STDERR "There are no peds and maps directories in the directory $RNA_Path. They were either moved, renamed or deleted.\n";
    print STDERR "Please run script 1.1_Birdseed_to_ped_and_maps.pl.\n";
    exit;
} 

chdir "$RNA_Path";

my $imputation = "$RNA_Path/phased";

`mkdir -p $imputation` unless(-d "$imputation");
`rm -f $imputation/*`;

`mkdir "$RNA_Path/logs"` unless(-d "$RNA_Path/logs");
`rm -f $RNA_Path/logs/*`;

my $OneKG_Ref_Path = "$database_path/ALL.integrated_phase1_SHAPEIT_16-06-14.nomono";

my $Phased_hap = "$imputation";

my $Impute2out = "$Analysispath/$disease_abbr/phased_imputed_raw_out";

#submit_shapeit(path to ALL.integrated_phase1_SHAPEIT_16-06-14.nomono,path to the RNA_Seq_Analysis directory,user defened directory from command line or default directory)
my @shapeit_cmds = $impute_plink->submit_shapeit("$OneKG_Ref_Path","$RNA_Path","$imputation");

mce_map {
      system("$shapeit_cmds[$_]");
                  } 0..$#shapeit_cmds;

#fetch_Chrom_Sizes(reference genome(e.g. hg19))
$impute_plink->fetch_Chrom_Sizes("hg19");

`cat chr_lens_grep_chr | grep -v Un | grep -v random | grep -v hap | grep -v M | grep -v Y | grep chr > chr_lens`;

`cat chr_lens|head -n 11 > file_for_submit`;

mkdir "$Impute2out" unless(-d "$Impute2out");
#submit first 11 chrs for imputation
#submit_all(file with chr sizes,path to ALL.integrated_phase1_SHAPEIT_16-06-14.nomono,user defened directory from command line or default directory,path to phased_imputed_raw_out)
my @imput2cmds = $impute_plink->submit_all("file_for_submit", $OneKG_Ref_Path, $Phased_hap, $Impute2out);

mce_map {
      system("$imput2cmds[$_]");
                  } 0..$#imput2cmds;

#To save disk space;
#remove them permentately!
`rm -f $Impute2out/*_allele_probs`;
`rm -f $Impute2out/*_info_by_sample`;
`rm -f $Impute2out/*_info`;
`rm -f $Impute2out/*_summary`;
`rm -f $Impute2out/*_warnings`;

`cat chr_lens|tail -n 12 > file_for_submit`;
#submit next 12 chrs for imputation
undef @imput2cmds;
@imput2cmds = $impute_plink->submit_all( "file_for_submit", $OneKG_Ref_Path, $Phased_hap, $Impute2out);
mce_map
{
            system("$imput2cmds[$_]");

} 0..$#imput2cmds;

#To save disk space;
#remove them permentately!
`rm -f $Impute2out/*_allele_probs`;
`rm -f $Impute2out/*_info_by_sample`;
`rm -f $Impute2out/*_info`;
`rm -f $Impute2out/*_summary`;
`rm -f $Impute2out/*_warnings`;

print "All jobs are done for $disease_abbr.\n";

$time = localtime;
print "Script finished on $time.\n";

exit;
