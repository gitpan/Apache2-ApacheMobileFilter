#file:Apache2/AMFWebService.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 01/08/10
# Site: http://www.idelfuschini.it
# Mail: idel.fuschini@gmail.com

  package Apache2::AMFWebService;
  
  use strict;
  use warnings;
  use Apache2::AMFCommonLib ();
  
  use Apache2::Filter ();
  use Apache2::RequestRec ();
  use APR::Table ();
  use Cache::FileBackend;
  
  use Apache2::Const -compile => qw(OK);
  
  use constant BUFF_LEN => 1024;
  use vars qw($VERSION);
  $VERSION= "3.25";
  #
  # Define the global environment
  #
  my $CommonLib = new Apache2::AMFCommonLib ();
  my $cachedirectorystore="notdefined";

  $CommonLib->printLog("---------------------------------------------------------------------------"); 
  $CommonLib->printLog("AMFWebService Version $VERSION");
  
  if ($ENV{RestMode}) {
	
      } else {
      $CommonLib->printLog("RestMode must be setted not exist. Please set the variable RestMode into httpd.conf");      
  }

  sub handler {
      my $f = shift;
      my $query_string=$f->r->args;
      my $id;
      my $ua;
      my $capab;
      my %ArrayQuery;
      my %ArrayForSort;
      my %ArrayPnotes;
      my $type="xml";
      unless ($f->ctx) {
          $f->r->headers_out->unset('Content-Length');
          $f->ctx(1);
      }
      
      if ($query_string) {
    		  my @vars = split(/&/, $query_string); 	  
    		  foreach my $var (sort @vars){
    				   if ($var) {
    						my ($v,$i) = split(/=/, $var);
    						$v =~ tr/+/ /;
    						$v =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    						$i =~ tr/+/ /;
    						$i =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    						$i =~ s/<!--(.|\n)*-->//g;
    						$ArrayQuery{$v}=$i;
    					}
    		  }
    	  if ($ArrayQuery{type}) {
    				$type=$ArrayQuery{type};
    	  }

      }
      
      my $Hash=$f->r->subprocess_env();
      my $html_page;
      my $content_type="text/xml";
      if ($type ne 'json' && $type ne 'xml') {
            $type='xml';
      }
      if ($type eq 'json') {
            $content_type="text/plain";
      }
      if ($type eq 'xml') {
            $html_page='<?xml version="1.0" encoding="UTF-8"?><AMF_DEVICE_DETECTION>';
      }
      if ($type eq 'json') {
            $html_page='{"AMF_DEVICE_DETECTION": {'."\n";
      }
      my $count=0;
      while ( my ($key, $value) = each(%$Hash) ) {
            if (substr($key,0,4) eq 'AMF_') {
                  $key=substr($key,4,length($key));
                  if ($count > 0) {
                        $html_page=$html_page.",\n";
                  }
                  if ($type eq 'xml') {
                        $html_page=$html_page."<$key>$value</$key>";
                  }
                  if ($type eq 'json') {
                        $html_page=$html_page."             \"$key\":\"$value\"";
                        $count++;
                  }

            }
      }
      if ($type eq 'xml') {
            $html_page=$html_page.'</AMF_DEVICE_DETECTION>';
      }
      if ($type eq 'json') {
            $html_page=$html_page."\n     }\n}";
      }
      my $len_bytes=length $html_page;
      $f->r->headers_out->set("Content-Length"=>$len_bytes);
      $f->r->headers_out->set("Last-Modified" => time());
      $f->r->content_type($content_type);
      $f->print($html_page);
      return Apache2::Const::OK;
  }
  1;
=head1 NAME

Apache2::AMFWebService - This module give the result of Device Detection as WebService 

=head1 DESCRIPTION

This module give the info as WebService

=head1 SEE ALSO

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html

Demo page of the filter: http://www.apachemobilefilter.org

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=head1 COPYRIGHT

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut