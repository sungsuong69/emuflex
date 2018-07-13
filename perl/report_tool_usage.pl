####!/usr/bin/env perl

######################################################################
#
# $Header$
#
#--
#-- Usage : report_tool_usage.pl[ -h|--help ] [-v]
#--                      --input|-i file 
#--
#--     options: --help|-h           help page
#--              -v                  Verbose output
#--              --input|-i  file    Input file.
#--
#-- Function:
#--    taking cadence log file and producing the tool usage
#--
#
######################################################################

use warnings;

use Getopt::Long qw(:config no_ignore_case bundling);
use XML::Simple;
use Time::Local;
use Date::Calc qw(check_date check_time);
use Data::Dumper;
require  'dumpvar.pl';

############################### GLOBALS ##########################

my $exit_code = 0;
my $execname = $0;
my $infile;
my $verbose;
#my $today=`date '+%d %b %Y'`; chomp $today;
my $indent_spaces=3;
my $sepstr_len=80;

############################### USAGE Subroutine ##########################

sub usage { $MyName = $execname;
            open MyName;
            while (<MyName>)
               {
               print if s/^#--//;
               }
            exit $exit_code;
          }

####################### Case conversion #############################3
sub tolower {
   my ($str) = @_;
   $str =~ tr/A-Z/a-z/;
   return $str;
   }

sub toupper {
   my ($str) = @_;
   $str =~ tr/a-z/A-Z/;
   return $str;
   }

####################### Integer conversion Subroutine ##########################

sub convint {
   my ($val) = @_;
   if ($val =~ /^0x/) {
      warn "non-numeric character in value $val\n" unless ($val =~ /^0x[\da-f]+$/i);
      return oct($val);   ### oct does hex aswell!!
      }
   else {
      warn "non-numeric character in value $val\n" if ($val =~ /[^\d]/);
      $val =~ s/[^0-9]/0/g; # to save arith errors in use of this
      return $val;
      }
   }

####################### Die/Warn with script name ##########################

sub mydie {
   my $str       = shift;
   $str = "\nERROR: $execname: $str\n";
   die $str;
   }

sub mywarn {
   my $str       = shift;
   $str = "WARNING: $execname: $str\n";
   warn $str;
   $exit_code = 1;
   }

######################## Convert value to binary string ##################
# params: val  - convint format integer to convert
#         bits - number of binary bits to display
sub convbin {
   my ($val, $bits) = @_;
   my $retval = "";

   local ($intval) = &convint($val);
   for ($i=$bits-1; $i >= 0; $i--) {
      $retval = $retval . (($intval >> $i) & 1 == 1 ? "1" : "0");
      }
   return $retval;
   }

######################## Sort by chars, numbers ##################
# params: $a $b from "sort"
#         Use: sort aphanumsort @array
# Useful for correctly sorting things like msg1 msg2 .. msg10 .. msg20

sub alphanumsort () {

   my $atxt = "a";
   my $btxt = "a";
   my $anum = 0;
   my $bnum = 0;
   if ($a =~ m/([a-zA-Z]+)/) {$atxt = $1;}
   if ($b =~ m/([a-zA-Z]+)/) {$btxt = $1;}
   if ($a =~ m/(\d+)/)       {$anum = $1;}
   if ($b =~ m/(\d+)/)       {$bnum = $1;}

   #print "DEBUG: $a $b $atxt $btxt $anum $bnum\n";
   # sort by text, then numeric
   ($atxt and $btxt ? $atxt cmp $btxt : 0)
     or
   ($anum and $bnum ? $anum <=> $bnum : 0)
   ;
}

######################## Max string length ##################
sub max_string_len {
   my @strings=@_;
   if (@strings) {
      my $first=1;
      my $max = (sort {length($b)<=>length($a)} @strings)[0];
      return length($max);
      }
   else {
      return 0;
      }
   }

######################## Next 2^n boundary ##################
sub next_2n {
   my $val = shift;

   my $bdy = 1;
   while ($bdy < $val) {
      $bdy = $bdy<<1;
      }
   return $bdy;
   }

######################## Log 2 ##################
sub log2 {
   my $val = shift;

   my $bdy = 1;
   my $bits= 0;
   while ($bdy < $val) {
      $bdy = $bdy<<1;
      $bits++;
      }
   return $bits;
   }

######################## Kill Handler ##################
sub kill_handler {
   print STDERR "\nKilled...\n";
   exit 1;
   }

$SIG{INT} = \&kill_handler;

############################### Parse options #########################
#
# At the end of this operation, ARGV will have been left shifted to
# get rid of options used.
#
GetOptions(
           "help|h"                => \&usage,
           "v"                     => \$verbose,
           "input|i=s"             => \$infile,
          ) or mydie "Bad usage. Try -h or --help\n";


#===============================================================
sub dec_indent {
#===============================================================
   my $indentref = shift;
   if (length($$indentref) < $indent_spaces) {
      mydie "dec_indent: indent goes negative!";
   }
   $$indentref = ' ' x (length($$indentref) - $indent_spaces);
}

#===============================================================
sub remove_non_numeric{
#===============================================================
   my $var = shift;
   $var =~ s/[a-zA-Z=]//g;
   return $var;
}
#===============================================================
sub remove_non_char{
#===============================================================
   my $var = shift;
   $var =~ s/[\d:]//g;
   return $var;
 }

#===============================================================
sub print_my_hash{
#===============================================================
   my $hash = shift;
   my $key_only = shift;
   foreach (keys %$hash) {
   	  #next unless $_ =~ /fel_fm_pd(\.proto)/ or not defined $key_only;
      print "key = $_ ";
      print ", value = $hash->{$_} " unless defined $key_only;
      print "\n";
      print_my_hash($hash->{$_});
   }
}
################################# Main Body ###########################
## READERS: Jump to the bottom of the file to see sequence of sub calls
#######################################################################

mydie "Infile is a mandatory option (-i or --input)" unless ($infile);
mydie "Cannot find input file $infile" unless (-r $infile);

$hash = {};
$project_hash_report = {};
open(INFILE,  "$infile")  or mydie "Couldn't open $infile";
while($line =  <INFILE>){
   next unless ($line !~ /root/);
   next unless ($line !~ /DIAGS/);
   next if ($line =~ /^\s*\(nsimc2\)\s*$/);
   process_checkout($line) if($line =~ /opened/i);
   process_checkin($line) unless($line =~ /opened/i);
}

close INFILE;
#print_my_hash($hash,"key_only");
#print calculate_duration("2016/06/29","15:43:07","2016/06/29","15:43:53 ");

cleanup_project_hash_report();
init_project_hash_report();
#print_my_hash($project_hash_report,"key_only");
generate_project_hash_report();
#print_my_hash($project_hash_report,"key_only");
#print_project_hash_report($project_hash_report);
#dumpValue(\$project_hash_report);
print Dumper($project_hash_report);

################################# Main Body############################
## End of main bo
####################################################################
#===============================================================
sub print_project_hash_report{
#===============================================================
   my $hash = shift;
   foreach (keys %$hash) {
   	  print_horizontal_line();
   	  print_project_name($_);
   	  print_horizontal_line();
   	  #next unless $_ =~ /fel_fm_pd(\.proto)/ or not defined $key_only;
      #print "key = $_ ";
      #print "\n";
      #print_my_hash($hash->{$_});
      print_month_hash($hash->{$_});
   	  print_horizontal_line();
   }
}

#===============================================================
sub print_horizontal_line{
#===============================================================
   print "#", "=" x 100, "#","\n";
}
#===============================================================
sub print_project_name{
#===============================================================
   my $project_name = shift;
   my $p = "#";
   printf "#%50s", $project_name;
   printf "%51s",$p;
   print "\n";
}
#===============================================================
sub print_month_hash{
#===============================================================
   my $months = shift;
   #print "number of months = ", scalar(%$months),"\n";
   my $p = "#";
   my $vertical_bar = "|";
   print $vertical_bar;
   foreach (keys %$months) {
      printf("%25s%25s", $_,$vertical_bar);
   }
   print "\n";
}
#===============================================================
 sub remove_day{
#===============================================================
   my $date = shift;
   $date =~ s/(.*)\/.*?$/$1/;
   #print $date, "\n";
   return $date;
}

#===============================================================
 sub check_date_field{
#===============================================================
   my ($date,$time) = @_;
   my ($year,$mon,$mday) = split(/\//, $date);
   my ($hour,$min,$sec) = split(/:/, $time);

   #print "check_date_field:: ", $year , " ", $mon, " ", $mday, "\n" unless check_date($year,$mon,$mday);
   #print "check_date_field:: ", $hour , " ", $min, " ", $sec, "\n"  unless check_time($hour,$min,$sec) ;
   return check_date($year,$mon,$mday) &&  check_time($hour,$min,$sec);

}
#===============================================================
 sub cleanup_project_hash_report{
#===============================================================
   foreach (keys %$hash){
   	   unless($hash->{$_}->{'current_status'} eq "closed"){
          delete $hash->{$_};
   	   }
   }
}
#===============================================================
 sub init_project_hash_report{
#===============================================================
   foreach (keys %$hash){
       my $date_key = $hash->{$_}->{'date_checkout'};
       $date_key = remove_day($date_key);
       my $project_name = $hash->{$_}->{'project_name'};
       $project_hash_report->{$project_name}->{$date_key}->{'total_checkout_duration'} = 0;
       $project_hash_report->{$project_name}->{$date_key}->{'total_domain_used'} = 0;
   }
}
#===============================================================
 sub make_domain_list{
#===============================================================
   my $domain_used = shift;
   my $domain_list = [];
   my @temp_list = split(/\s+/,$domain_used);
   #print @temp_list, "\n";
   my $loop_index = 0;
   foreach (@temp_list){
   	  next unless /\d/;
   	  #print "domain = ",$_, "\n";
      if (/(\d+)-(\d+)/){
      	splice(@$domain_list,$loop_index,0,int($1)..int($2));
      	next;
      }
      push(@$domain_list,$_);

      $loop_index++;
   }
   return $domain_list;
}
#===============================================================
 sub generate_project_hash_report{
#===============================================================
   foreach (keys %$hash){
       my $date_key = $hash->{$_}->{'date_checkout'};
       $date_key = remove_day($date_key);
       my $checkout_date = $hash->{$_}->{'date_checkout'};
       my $checkout_time = $hash->{$_}->{'time_checkout'};
       my $checkin_date = $hash->{$_}->{'date_checkin'};
       my $checkin_time = $hash->{$_}->{'time_checkin'};
       my $project_name = $hash->{$_}->{'project_name'};
       my $domain_used = $hash->{$_}->{'domain_used'};
       mydie("check_date_field failed!!!! pid = " . $_) unless ( check_date_field($checkin_date,$checkin_time));

   	   #next unless $project_name eq "fm_p.(.proto)";
       #print "project pid  ", $_, " ", "domain used  ", $domain_used, "\n";
       my $domain_list = make_domain_list($domain_used);
       #print "domain_list = ", @$domain_list, "\n";
       #print "number of domain_list used = ", scalar(@$domain_list), "\n";
       #print "1) in hash  duration checkout ",$project_hash_report->{$project_name}->{$date_key}->{'checkout_duration'}, "\n";
       #print "1) in hash total duration checkout ",$project_hash_report->{$project_name}->{$date_key}->{'total_checkout_duration'} , "\n";
       my $duration_checkout = calculate_duration($checkout_date,$checkout_time,$checkin_date,$checkin_time);
       $project_hash_report->{$project_name}->{$date_key}->{'total_checkout_duration'} += $duration_checkout;
       $project_hash_report->{$project_name}->{$date_key}->{'checkout_duration'} = $duration_checkout;
       $project_hash_report->{$project_name}->{$date_key}->{'total_domain_used'} += scalar(@$domain_list);
       $project_hash_report->{$project_name}->{$date_key}->{'number_of_domain_used'} = scalar(@$domain_list);
       #print "duration checkout ", $duration_checkout, "\n";
       #print "2) in hash  duration checkout ",$project_hash_report->{$project_name}->{$date_key}->{'checkout_duration'}, "\n";
       #print "2) in hash total duration checkout ",$project_hash_report->{$project_name}->{$date_key}->{'total_checkout_duration'} , "\n";
   }
}
#===============================================================
 sub calculate_duration{
#===============================================================
   my $checkout_date = shift;
   my $checkout_time = shift;
   my $checkin_date = shift;
   my $checkin_time = shift;
   my ($checkout_year,$checkout_mon,$checkout_day) = split(/\//,$checkout_date);
   my ($checkout_hour,$checkout_min,$checkout_second) = split(/:/,$checkout_time);
   #print "checkout ", $checkout_hour, " " , $checkout_min, " " , $checkout_second, "\n";
   my ($checkin_year,$checkin_mon,$checkin_day) = split(/\//,$checkin_date);
   #print "checkin" , $checkin_year, " " , $checkin_mon, " " , $checkin_day, "\n";
   my ($checkin_hour,$checkin_min,$checkin_second) = split(/:/,$checkin_time);
   #print "checkin", $checkin_hour, " " , $checkin_min, " " , $checkin_second, "\n";
   $checkout_mon -= 1;
   $checkin_mon -= 1;
   my $checkout_time_in_second = timelocal($checkout_second,$checkout_min,$checkout_hour,$checkout_day,$checkout_mon,$checkout_year);
   my $checkin_time_in_second = timelocal($checkin_second,$checkin_min,$checkin_hour,$checkin_day,$checkin_mon,$checkin_year);
   #print $checkin_time_in_second, "\n";
   #print $checkout_time_in_second, "\n";
   return $checkin_time_in_second - $checkout_time_in_second;
}
#===============================================================
sub process_checkout{
#===============================================================
    my $line =  shift;
    print $line if defined $verbose ;
    my ($date_checkout,$time_checkout,$junk,$user,$pid,$status,$board_junk,@rest_of_line) = split(/\s+/,$line);
    $line =~ m/.*?Boards\s+(\d+.*?)\s+for\s+(\/.*?)\s+.*/;
    my $domain_var = $1;
    my $project_var = $2;
    print "=====================\n" if defined $verbose;
    $user = remove_non_char($user);
    $pid = remove_non_numeric($pid);
    my $project_name = get_project_name($project_var);
    my $board_name = get_board_name($domain_var);
    my $domain_used;
    if($domain_var =~ m/[,]/){
        my @domain_array = split(/[,]/,$domain_var);
        #print @domain_array;
        #exit;
        foreach $domain (@domain_array){
            $domain_used .= " " . get_domain_used($domain);
         }
    }
    else{
        $domain_used = get_domain_used($domain_var);
    }
    print $user, " ", $pid, " ", $date_checkout, " " , $time_checkout, " ",$board_name, " ",$domain_used," ",$project_name,"\n" if defined $verbose;

    return unless $status eq "opened";

    $hash->{$pid}->{'user'} = $user;
    $hash->{$pid}->{'date_checkout'} = $date_checkout;
    $hash->{$pid}->{'time_checkout'} = $time_checkout;
    $hash->{$pid}->{'board_name'} = $board_name;
    $hash->{$pid}->{'domain_used'} = $domain_used;
    $hash->{$pid}->{'project_name'} = $project_name;
    $hash->{$pid}->{'current_status'} = $status;
}
#===============================================================
 sub process_checkin{
#===============================================================
    my $line =  shift;
    print $line if defined $verbose ;
    my ($date_checkin,$time_checkin,$junk,$user,$pid,$status,$for_junk,$project_var,$rest_of_line) = split(/\s+/,$line);
    print "=====================\n" if defined $verbose;
    $user = remove_non_char($user);
    $pid = remove_non_numeric($pid);
    my $project_name = get_project_name($project_var);
    #print $user, " ", $pid, " ", $date_checkin, " ", $status, " " , $time_checkin, " ",$project_name,"\n";
    unless ($status eq "closed"){
    	delete $hash->{$pid} if exists $hash->{$pid};
    	return;
    }

    print $user, " ", $pid, " ", $date_checkin, " ", $status, " " , $time_checkin, " ",$project_name,"\n" if defined $verbose;

    return unless exists $hash->{$pid};
    $hash->{$pid}->{'date_checkin'} = $date_checkin;
    $hash->{$pid}->{'time_checkin'} = $time_checkin;
    $hash->{$pid}->{'current_status'} = $status;
}
#===============================================================
 sub get_board_name{
#===============================================================
    my $domain_var = shift;
    $domain_var =~ m/^\s*(\d+)\..*/;
    return $1;
 }
#===============================================================
 sub get_domain_used{
#===============================================================
   my $domain_used = shift;
   if($domain_used =~ m/^\s*(\d+)\.(\d+)(.)(\d+)\.(\d+)/){
       $domain_used = "$2$3$5";
   }
   elsif ($domain_used =~ m/[,]/){
   }
   else{
       $domain_used =~ s/^\s*(\d+)\.(\d+)/$2/;
   }
   return $domain_used;
 }


#===============================================================
 sub get_project_name{
#===============================================================
    my $project_var = shift;
    my @project_name_array = split(/\//,$project_var);
    my $project_name = $project_name_array[-1];
    return $project_name;
}

##---------------------------------------------------------------------
exit $exit_code;
