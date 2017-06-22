################################################################################
#          _____ _
#         |_   _| |_  ___
#           | | | ' \/ -_)
#           |_| |_||_\___|
#                   _   _             ____            _           _
#    / \   _ __ ___| |_(_) ___ __ _  |  _ \ _ __ ___ (_) ___  ___| |_
#   / _ \ | '__/ __| __| |/ __/ _` | | |_) | '__/ _ \| |/ _ \/ __| __|
#  / ___ \| | | (__| |_| | (_| (_| | |  __/| | | (_) | |  __/ (__| |_
# /_/   \_\_|  \___|\__|_|\___\__,_| |_|   |_|  \___// |\___|\___|\__|
#                                                  |__/
#          The Arctica Modular Remote Computing Framework
#
################################################################################
#
# Copyright (C) 2015-2016 The Arctica Project
# http://arctica-project.org/
#
# This code is dual licensed: strictly GPL-2 or AGPL-3+
#
# GPL-2
# -----
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
#
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
#
# AGPL-3+
# -------
# This programm is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This programm is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Copyright (C) 2015-2016 Guangzhou Nianguan Electronics Technology Co.Ltd.
#                         <opensource@gznianguan.com>
# Copyright (C) 2015-2016 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
#
################################################################################
package Arctica::Services::Audio::Streamer::ClientGST;
use strict;
use Exporter qw(import);
use Arctica::Core::BugOUT::Basics qw( BugOUT );
use Arctica::Core::Mother::Forker;
use Time::HiRes qw( usleep );
use Data::Dumper;# Remove this before release! (unless we're still dependant)

# Be very selective about what (if any) gets exported by default:
our @EXPORT = qw( );
# And be mindfull of what we lett the caller request here too:
our @EXPORT_OK = qw( );

my $arctica_core_object;

sub new {
	BugOUT(9,"ClientGST new->ENTER");
	my $class_name = $_[0];# Be EXPLICIT!! DON'T SHIFT OR "@_";
	$arctica_core_object = $_[1];
#	my $JBUS_Server = $_[2];
	my $self = {
		isArctica => 1, # Declare that this is a Arctica "something"
		aobject_name => "ClientGST",
		default_out_rate => 64,
		default_in_rate => 32,
	};

	bless($self, $class_name);

	$arctica_core_object->{'aobj'}{'AudioClient'}{'ClientGST'} = \$self;

	BugOUT(9,"ClientGST new->DONE");
	return $self;
}


sub start_output {
	BugOUT(9,"ClientGST start_output->ENTER");
	my $self = $_[0];
	my $idnum = $_[1];
	my $run_on_ready = $_[2];
	if ($idnum =~ /^(\d{1,3})$/) {
		$idnum = $1;
	}  else {
		$idnum = "";
		die;
	}
	my ($dsoc_type,$dsoc_port) = $self->get_device_port_and_soc_type("output",$idnum);

	if ($dsoc_type and $dsoc_port) {
		$self->{'vdev'}{'output'}{$idnum}{'running'} = 1;
		$self->{'vdev'}{'output'}{$idnum}{'gst_thread'} = Arctica::Core::Mother::Forker->new($arctica_core_object,{
			child_name	=>	'arctica-gst',
			fork_style	=>	'interactive_pty',
			handle_stdeoc	=>	sub {
				if ($_[0] =~ /^status:sink_ready:(\d{1,3}):$/) {
					$run_on_ready->($1);
				}
			},
			return_stdin	=>	1,
			exec_hold	=>	0,
			exec_path	=>	"/audiotest/bin/launch_client_ThreadGST",# FIXME LOAD FULL PATH FROM CFG OR SOMETHING LIKE THAT
			exec_cl_argv	=>	[
							"-snk=$dsoc_type",
							"-port=$dsoc_port",
							"-clientside=pulseaudio",
							"-idnum=$idnum",
						],
		});

	} else {
		BugOUT(1,"ClientGST start_output port and socket type not set?!! WTF?! ($dsoc_type,$dsoc_port)");
	}
	BugOUT(9,"ClientGST start_output->DONE");
}



sub stop_output {
	BugOUT(9,"ClientGST stop_output->ENTER");
	my $self = $_[0];
	my $idnum = $_[1];
	if ($self->{'vdev'}{'output'}{$idnum}{'gst_thread'}) {
		$self->{'vdev'}{'output'}{$idnum}{'running'} = 0;
		BugOUT(9,"Stop GST thread: output $idnum");
		$self->{'vdev'}{'output'}{$idnum}{'gst_thread'}->send("cmd:stop:");
	} else {
		BugOUT(1,"Stop GST thread: FAIL (output $idnum)");
	}
	BugOUT(9,"ClientGST stop_output->DONE");
}

sub start_input {
	BugOUT(9,"ClientGST start_input->ENTER");
	my $self = $_[0];
	my $idnum = $_[1];
	if ($idnum =~ /^(\d{1,3})$/) {
		$idnum = $1;
	}  else {
		$idnum = "";
		die;
	}
	my $bitrate = $_[2];

	if ($bitrate =~ /^(\d{1,3})$/) {
		$bitrate = $1;
	} else {
		$bitrate = 0;
	}

	my ($dsoc_type,$dsoc_port) = $self->get_device_port_and_soc_type("input",$idnum);

	if ($dsoc_type and $dsoc_port) {
		$self->{'vdev'}{'input'}{$idnum}{'running'} = 1;
		$self->{'vdev'}{'input'}{$idnum}{'gst_thread'} = Arctica::Core::Mother::Forker->new($arctica_core_object,{
			child_name	=>	'arctica-gst',
			fork_style	=>	'interactive_pty',
			handle_stdeoc	=>	sub {return 1;},
			return_stdin	=>	1,
			exec_hold	=>	0,
			exec_path	=>	"/audiotest/bin/launch_client_ThreadGST",# FIXME LOAD FULL PATH FROM CFG OR SOMETHING LIKE THAT
			exec_cl_argv	=>	[
							"-src=$dsoc_type",
							"-port=$dsoc_port",
							"-start_bitrate=$bitrate",
							"-clientside=pulseaudio",
							"-idnum=$idnum",
						],
		});
	} else {
		BugOUT(1,"ClientGST start_output port and socket type not set?!! WTF?! ($dsoc_type,$dsoc_port)");
	}
	BugOUT(9,"ClientGST start_input->DONE");
}


sub stop_input {
	BugOUT(9,"ClientGST stop_input->ENTER");
	my $self = $_[0];
	my $idnum = $_[1];
	if ($self->{'vdev'}{'input'}{$idnum}{'gst_thread'}) {
		$self->{'vdev'}{'input'}{$idnum}{'running'} = 0;
		BugOUT(9,"Stop GST thread: input $idnum");
		$self->{'vdev'}{'input'}{$idnum}{'gst_thread'}->send("cmd:stop:");
	} else {
		BugOUT(1,"Stop GST thread: FAIL (input $idnum)");
	}
	BugOUT(9,"ClientGST stop_input->DONE");
}


sub set_bitrate {
	BugOUT(9,"ClientGST set_bitrate->ENTER");
	my $self = $_[0];
	my $new_input_rate = $_[1];

	if ($new_input_rate > 0) {
			foreach my $idnum (keys %{$self->{'vdev'}{'input'}}) {
				if ($self->{'vdev'}{'input'}{$idnum}{'running'}) {
					if ($self->{'vdev'}{'input'}{$idnum}{'gst_thread'}) {
						$self->{'vdev'}{'input'}{$idnum}{'gst_thread'}->send("set:bitrate:$new_input_rate");
					}
				}
			}
			BugOUT(9,"Input bitrate set to $new_input_rate");
	} else {
		BugOUT(9,"Input bitrate is unchanged...");

	}
	BugOUT(9,"ClientGST set_bitrate->DONE");
}



sub set_device_socket_type  {
	BugOUT(9,"ClientGST set_device_socket_type->ENTER");
	my $self = $_[0];

	if (($_[1] eq "tcp") or ($_[1] eq "unixs")) {
		$self->{'_settings'}{'socket_type'} = $_[1];
		$self->{'_settings'}{'com_style'} = "stream";
		BugOUT(9,"set_device_socket_type: socket type set to $_[1]/stream");
	} elsif (($_[1] eq "udp") or ($_[1] eq "unixd")) {
		$self->{'_settings'}{'socket_type'} = $_[1];
		$self->{'_settings'}{'com_style'} = "datagram";
		BugOUT(9,"set_device_socket_type: socket type set to $_[1]/datagram");
	} else {
		BugOUT(0,"set_device_socket_type: '$_[1]' is not a valid socket_type");
	}

	BugOUT(9,"ClientGST set_device_socket_type->DONE");
}


sub set_device_gst_port {
	BugOUT(9,"ClientGST set_device_gst_port->ENTER");
	my $self = $_[0];
	my $device = $_[1];
	my $port = $_[2];

	if ($device =~ /^o(\d{1,})/) {
		$self->{'vdev'}{'output'}{$1}{'port'} = $port;
		BugOUT(9,"set_device_gst_port: output:$1:$port");
	} elsif ($device =~ /^i(\d{1,})/) {
		$self->{'vdev'}{'input'}{$1}{'port'} = $port;
		BugOUT(9,"set_device_gst_port: input:$1:$port");
	} else {
		BugOUT(2,"set_device_gst_port: Failed to set device '$device' port to '$port'");
	}

	BugOUT(9,"ClientGST set_device_gst_port->DONE");
}


sub get_device_port_and_soc_type {
	my $self = $_[0];
	my $type = $_[1];
	my $idnum = $_[2];

	my $soc_type = $self->{'_settings'}{'socket_type'};
	if ($soc_type =~ /^([a-z]{3,6})$/) {
		$soc_type = $1;
	} else {
		$soc_type = 0;
	}

	if (($soc_type eq "tcp") or ($soc_type eq "udp")) {
		if ($self->{'vdev'}{$type}{$idnum}{'port'}) {
			my $port = $self->{'vdev'}{$type}{$idnum}{'port'};
			if ($port =~ /^(\d{2,5})$/) {
				$port = $1;
			} else {
				$port = 0;
			}

			if (($soc_type ne 0) and ($port ne 0)) {
				return ($soc_type,$port);
			}
		}
	}
}


1;
