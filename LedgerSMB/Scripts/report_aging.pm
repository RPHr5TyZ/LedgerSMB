=head1 NAME

LedgerSMB::Scripts::report_aging - Aging Reports and Statements for LedgerSMB

=head1 SYNOPSIS

This module provides AR/AP aging reports and statements for LedgerSMB.

=head1 METHODS

=cut

package LedgerSMB::Scripts::report_aging;
our $VERSION = '1.0';

use LedgerSMB;
use LedgerSMB::Template;
use LedgerSMB::DBObject::Business_Unit;
use LedgerSMB::DBObject::Report::Aging;
use strict;

=pod

=over

=item run_report

Runs the report and displays it

=cut

sub run_report{
    my ($request) = @_;

    delete $request->{category} if ($request->{category} = 'X');
    $request->{business_units} = [];
    for my $count (1 .. $request->{bc_count}){
         push @{$request->{business_units}}, $request->{"business_unit_$count"}
               if $request->{"business_unit_$count"};
    }
    LedgerSMB::DBObject::Report::Aging->prepare_criteria($request);
    my $report = LedgerSMB::DBObject::Report::Aging->new(%$request);
    $report->run_report;
    $report->render($request);
}


=item select_all

Runs a report again, selecting all items

=cut

sub select_all {
    run_report(@_);
}

=item generate_statement

This generates a statement and sends it off to the printer, the screen, or
email.

=cut

sub generate_statement {
    my ($request) = @_;
    use LedgerSMB::DBObject::Entity::Company;
    use LedgerSMB::DBObject::Entity::Credit_Account;
    use LedgerSMB::DBObject::Entity::Location;
    use LedgerSMB::DBObject::Entity::Contact;

    my $rtype = $request->{report_type}; # in case we need it later
    $request->{report_type} = 'detail'; # needed to generate statement

    my $template_suffix;
    my @statements;
    my $old_meta = $request->{meta_number};

    # The reason to work backwards here is that if we are sending emails out, we 
    # can hide form submission info and not lose track of where we are.  This
    # will need additional documentation, however.  --CT
    while ($request->{rowcount} > 0){
        my $rc = $request->{rowcount};
        --$request->{rowcount};
        next unless $request->{"select_$rc"};
        my ($entity_id, $meta_number) = split /:/, $request->{"select_$rc"};
        my $company = LedgerSMB::DBobject::Entity::Company->get($entity_id);
        my $credit_act = 
              LedgerSMB::DBobject::Entity::Credit_Account->get_by_meta_number(
                 $meta_number, $request->{entity_class}
        );
        my @loc = LedgerSMB::DBobject::Entity::Location->get_active(
             $request, {entity_id => $entity_id, 
                        credit_id => $credit_act->{id},
                       only_class => 1}
        );
        my $location = pop @loc;
        my @contact_info = LedgerSMB::DBObject::Entity::Contact->list(
                 {entity_id => $entity_id, credit_id => $credit_act->{id} }
        );
        $request->{meta_number} = $meta_number;
        LedgerSMB::DBObject::Report::Aging->prepare_criteria($request);
        my $aging_report = LedgerSMB::DBObject::Report::Aging->new(%$request);
        my $statement = {
              aging => $aging_report,
             entity => $company,
            address => $location,
           contacts => @contact_info
        };
        push @statements, $statement;
        last if $request->{print_to} eq 'email';
    }
    $request->{report_type} = $rtype;
    $request->{meta_number} = $old_meta;

    my $template = LedgerSMB::Template->new(
        locale => $LedgerSMB::App_Date::Locale,
        template => $request->{print_template},
     #   language => $form->{language_code}, TODO
        format => uc $request->{print_format},
        method => $request->{print_to},
    );

    if ($request->{print_to} eq 'email'){ 
       #TODO -- mailer stuff
    } elsif ($request->{print_to} eq 'screen'){
        $template->render({statements => \@statements});
    } else {
        $template->render({statements => \@statements});
        use LedgerSMB::Scripts::reports;
        $request->{module_name}='gl';
        $request->{report_type}='aging';
        LedgerSMB::Scripts::reports::start_report($request);
    }   

}

=back

=head1 COPYRIGHT

Copyright (C) 2012 The LedgerSMB Core Team.  This file may be re-used under the
terms of te GNU General Public License version 2 or at your option any later
version.  Please see included LICENSE.txt for more info.

=cut

1;