use 5.14.2;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => "Die::Ception",
    ABSTRACT        => 'Die through several evals at once',
    VERSION_FROM    => "lib/Die/Ception.pm",
    LICENSE         => 'perl',
    DEFINE          => '-DDC_DEBUGGING',
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/rgs/Die-Ception.git',
                web  => 'https://github.com/rgs/Die-Ception',
            },
        },
    },
);
