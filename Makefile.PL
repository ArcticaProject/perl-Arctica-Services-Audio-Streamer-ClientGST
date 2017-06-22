use strict;
use ExtUtils::MakeMaker;

WriteMakefile (
  AUTHOR        => 'Arctica Project Developers',
  ABSTRACT      => "Arctica Service: Audio Streamer ClientGST",
  NAME          => 'Arctica::Services::Audio::Streamer::ClientGST',
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM     => {
    'Test::More' => '0.47',
  },
  VERSION_FROM  => 'lib/Arctica/Services/Audio/Streamer/ClientGST/Version.pm',
  clean               => { FILES => '' },
);
