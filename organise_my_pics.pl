#!/usr/bin/perl -w
use strict;
use warnings;
use File::Path qw(make_path);
use File::Glob;

# -----------------------------------------------------------------------------
# Photo organisation script.
# Author: John Creasey (john@creasey.id.au)
# Uses these external commands written by others:
#   convert (http://www.imagemagick.org) 
#   jhead (http://www.sentex.net/~mwandel/jhead/)
#
# EDIT THESE SETTINGS
my $Album      = glob("~/Album");         # Where to put the Album.
my $InstallDir = glob("~/organise_pics"); # Path(s) to find convert and jhead 
my $DirFormat  = '$Album/$year/$month';   # Directory structure to store photos.
my $MinRes     = 600;                     # Ignore anything smaller than this.
my $Do_Rotate  = 1;                       # Try to rotate?  1=yes 0=no  
# -----------------------------------------------------------------------------


# Comment out the second two commands if you don't want pics resized.
my $Actions = [
                { 'prefix' => 'lge', 'cmd' => 'cp "%s" "%s/%s"' }, 
                { 'prefix' => 'med', 'cmd' => 'convert "%s" $rotate -resize 700x1400\\> "%s/%s"' },
                { 'prefix' => 'sml', 'cmd' => 'convert "%s" $rotate -thumbnail 140x280 -depth 8 -background black -polaroid 0 "%s/%s"' },
              ];


# Main
if ($#ARGV == -1)
{
    print "Photo organisation script\n$0 {<directory>}\n";
} 
else
{
    # Fix the path.
    local $ENV{PATH} = "$InstallDir:$ENV{PATH}";  

    make_path($Album);
    foreach my $entry (@ARGV)
    {
        Traverse($entry);
    }
}


sub ApplyAction
{
    my $file      = shift;
    my $dir       = shift;  
    my $timestamp = shift;
    my $action    = shift;
    my $rotate    = shift;

    my $to_dir  = "$dir/$action->{'prefix'}";
    my $to_file = "$action->{'prefix'}_${timestamp}.JPG";

    make_path($to_dir);

    if (-f "$to_dir/$to_file")
    {
        print "Skipping $to_dir/$to_file\n";
    }
    else
    {
        my $cmd = sprintf($action->{'cmd'}, $file, $to_dir, $to_file);
           $cmd =~ s/\$rotate/$rotate/;
        print "Running: $cmd\n";
        print `$cmd`;
    }
}


# Work out where this file should go and then apply each of the 
# Actions to put it there.
sub ReOrganise
{
    my $file      = shift;
    my $timestamp = shift;
    my $rotate    = shift;

    my @array  = split /[: ]/, $timestamp;

    my $year   = $array[0];
    my $month  = $array[1];
    my $day    = $array[2];
    my $hour   = $array[3];
    my $min    = $array[4];
    my $sec    = $array[5];

    my $time     = "${year}-${month}-${day}_${hour}-${min}-${sec}";
    my $date_dir = eval("sprintf(\"$DirFormat\")");
    foreach my $action (@$Actions)
    {
        ApplyAction ($file,$date_dir,$time,$action,$rotate);
    }
}


# Extract all the EXIF headers from the file.
sub ProcessFile
{
    my $path = shift;
    my $file = shift;

    my $full = "$path/$file";

    my %headers;
    foreach my $line (`jhead -se "$full"`)
    {
        chop $line;
        if ($line)
        {
            #Date/Time) = (2008:04:22 14:07:16)
    
            my ($token, $value) = split /[ ]*\:[ ]*/, $line, 2;
            $headers{$token} = $value;
        }
    }
    if (defined($headers{'Resolution'}))
    {
        $headers{'Resolution'} =~ /(\d+) x (\d+)/;
        if ($1 >= $MinRes && $2 >= $MinRes) 
        {
            my $rotate = '';
            if ($Do_Rotate && defined($headers{Orientation}))
            {
                $rotate = '-' . $headers{'Orientation'};
            }
            if (defined($headers{'Date/Time'})) 
            {
                ReOrganise ($full,$headers{'Date/Time'},$rotate); 
            }
        }
        else
        {
            print "Ignoring ($path) ($file) - Too Small\n";
        }
    }
}

# Look in every directory and subdirectory for JPG files.
sub Traverse
{
    my $path = shift;
    if (-d $path) 
    {
        opendir (my $dh, $path) || die "Can't opendir $path $!";
        for my $file (readdir $dh)
        {
            next if ($file =~ /^[.]+$/);
            if (-d "$path/$file") 
            {
                Traverse("$path/$file");
            }
            else
            {
                if (lc($file) =~ /.*\.jpg/)
                {
                    next if (lc($file) =~ /thumb.*/);
                    ProcessFile($path,$file);
                }
            }
        }
    }
}

