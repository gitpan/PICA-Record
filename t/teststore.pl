#!/usr/bin/perl

# tests for PICA::Store and subclasses (to be included in other tests)

sub teststore {
    my ($store) = @_;
    my (%result, $record);

    my @records = (
        PICA::Record->new("002@ \$0Aau\n021A \$aDas zweite Kapital\n028A \$dKarl\$aMarx"),
    );
    my $r = PICA::Record::getrecord('t/minimal.pica');
    $r->delete_fields('003@');

    my $i=0;

    while( @records ) {
        $record = shift @records;

        my %result = $store->create($record);
        ok( scalar %result, "create[$i]");
        isa_ok( $result{record}, "PICA::Record", "create[$i] returned a PICA::Record" );
        my $id = $result{id};
        ok( $id, "create[$i] returned an id: $id" );

        %result = $store->get( $id );
        isa_ok( $result{record}, "PICA::Record", "get($id) returned a PICA::Record" );
        ok( $id, "get($id) returned an id" );

        my $version = $result{version};
        my $history;

        if ($store->can('history')) {
            $history = $store->history( $id );
            is( scalar @$history, 1, "history for $id: 1" );
            is( $history->[0]->{version}, $version, "history contains version" );
            is( $history->[0]->{is_new}, 1, "history contains is_new" );
        }

        if (@records) {
            $record = $records[0];            
            %result = $store->update( $id, $record, $version );
            ok ($result{record} && $result{id}, "updateRecord($id)");
            if ($store->can('history')) {
                $history = $store->history( $id );
                is( scalar @$history, 2, "history for $id: 2" );
                is( $history->[0]->{is_new}, 0, "history contains is_new (0)" );
                is( $history->[1]->{is_new}, 1, "history contains is_new (1)" );
            }
        }

        %result = $store->delete( $id );
        is ( $result{id}, $id, "deleteRecord($id)" );

        if ($store->can('history')) {
            # $history = $store->history( $id );
            # print Dumper($history);
        }
        if ($store->can('recentchanges')) {
            # TODO ...
        }
        if ($store->can('deletions')) {
            # ...
        }

        $i++;
    }

    %result = $store->get( -1 );

    ok ($result{errorcode}, "getRecord of non-existing id");
}

1;