use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(

	# depend => { Makefile => '$(VERSION_FROM)' },

    'NAME'           => 'SML::Parser',
    'VERSION_FROM'   => 'Parser.pm', # finds $VERSION
    'PREREQ_PM'      => 
	                    { # e.g., Module::Name => 1.1
							strict			=> 0,
							warnings		=> 0,
							Test::Easy		=> 1.01,

						},
	# 'EXE_FILES'      => [qw( infoadmin infoedit )],
    ($] >= 5.005 ? (
      ABSTRACT_FROM  => 'Parser.pm', 
      AUTHOR         => 'Daniel Peder <Daniel.Peder@infoset.com>',
    ) : ()),
);


sub MY::postamble { q{

docs : README

README: Parser.pm
	pod2text --loose Parser.pm > README

xdist:
	[ -f MANIFEST ] && rm -f MANIFEST ; make realclean docs manifest tardist;

}; }
