use strict;
use Test::More;

#use  ExtUtils::Manifest;
#my @missing_files = ExtUtils::Manifest::manicheck();
#print join ("\nF:\n", @missing_files);

eval {
    require Test::Distribution;
};
if($@) {
    plan skip_all => 'Test::Distribution not installed';
} else {
    import Test::Distribution;
}

