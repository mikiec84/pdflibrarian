#!@PERL@

# Copyright (C) 2016--2018 Karl Wette
#
# This file is part of PDF Librarian.
#
# PDF Librarian is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# PDF Librarian is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with PDF Librarian. If not, see <http://www.gnu.org/licenses/>.

use v@PERLVERSION@;
use strict;
use warnings;

use Capture::Tiny;
use Carp;
use File::MimeInfo::Magic;
use Getopt::Long;
use Pod::Usage;
use Text::Unidecode;

@perl_use_lib@;
use pdflibrarian::config;
use pdflibrarian::util qw(progress extract_doi_from_pdf);
use pdflibrarian::query_dialog qw(do_query_dialog);
use pdflibrarian::bibtex qw(read_bib_from_str generate_bib_keys write_bib_to_fh edit_bib_in_fh write_bib_to_pdf);
use pdflibrarian::library qw(update_pdf_lib make_pdf_links cleanup_links);

=pod

=head1 NAME

B<pdf-lbr-import-pdf> - Import a PDF file into the PDF library.

=head1 SYNOPSIS

B<pdf-lbr-import-pdf> B<--help>|B<-h>

B<pdf-lbr-import-pdf> I<file>

=head1 DESCRIPTION

B<pdf-lbr-import-pdf> imports a PDF I<file> into the PDF library.

It will first try to determine a Digital Object Identifier from the contents of the PDF I<file>.

TODO

=head1 PART OF

PDF Librarian, version @VERSION@.

=cut

# handle help options
my ($help);
GetOptions(
           "help|h" => \$help,
          ) or croak "$0: could not parse options";
pod2usage(-verbose => 2, -exitval => 1) if ($help);

# check input
croak "$0: requires a single argument" unless @ARGV == 1;
my $pdffile = $ARGV[0];
croak "$0: '$pdffile' is not a PDF file" unless -f $pdffile && mimetype($pdffile) eq 'application/pdf';

# extract a DOI from PDF file, use for default query text
my $query_text = extract_doi_from_pdf($pdffile) // "";

# ask user for query database and query text
my $query_db_name = $pref_query_database;
my $error_message = '';
my $bibstr;
do {

  # ask user for query database and query text
  ($query_db_name, $query_text) = do_query_dialog($pdffile, $query_db_name, $query_text, $error_message);
  if (!defined($query_db_name)) {
    progress("import of PDF file '$pdffile' has been cancelled\n");
    exit 1;
  }

  # run query command
  my $query_cmd = sprintf("$query_databases{$query_db_name}", $query_text);
  my $exit_status;
  ($bibstr, $error_message, $exit_status) = Capture::Tiny::capture {
    system($query_cmd);
    if ($? == -1) {
      print STDERR "\n'$query_cmd' failed to execute: $!\n";
    } elsif ($? & 127) {
      printf STDERR "\n'$query_cmd' died with signal %d, %s coredump\n", ($? & 127),  ($? & 128) ? 'with' : 'without';
    } elsif ($? != 0) {
      printf STDERR "\n'$query_cmd' exited with value %d\n", $? >> 8;
    }
  };
  $bibstr =~ s/^\s+//;
  $bibstr =~ s/\s+$//;
  $error_message =~ s/^\s+//;
  $error_message =~ s/\s+$//;

} while ($error_message ne '');

# write BibTeX data to a temporary file for editing
my $fh = File::Temp->new(SUFFIX => '.bib', EXLOCK => 0) or croak "$0: could not create temporary file";
binmode($fh, ":encoding(iso-8859-1)");
{

  # try to parse BibTeX data
  my $bibentry;
  eval {
    $bibentry = read_bib_from_str($bibstr);
  };
  if (defined($bibentry)) {

    # set name of PDF file
    $bibentry->set('file', $pdffile);

    # generate initial key for BibTeX entry
    generate_bib_keys(($bibentry));

    # coerse entry into BibTeX database structure
    $bibentry->silently_coerce();

    # write BibTeX entry
    write_bib_to_fh($fh, ($bibentry));

  } else {

    # try to add 'file' field to BibTeX data manually
    $bibstr =~ s/\s*}$/,\n  file = {$pdffile}\n}/;

    # write BibTeX data
    print $fh "\n$bibstr\n";

  }
}

# edit BibTeX data
my @bibentries = edit_bib_in_fh($fh, ());

# regenerate keys for BibTeX entry
generate_bib_keys(@bibentries);

# write BibTeX entry to PDF metadata
write_bib_to_pdf(@bibentries);

# add PDF file to library
update_pdf_lib(@bibentries);

# add links in PDF links directory to real PDF file
make_pdf_links(@bibentries);

# cleanup PDF links directory
cleanup_links();

exit 0;