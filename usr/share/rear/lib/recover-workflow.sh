# recover-workflow.sh
#
# recover workflow for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

WORKFLOW_recover_DESCRIPTION="recover the system; only valid during rescue"
WORKFLOWS=( ${WORKFLOWS[@]} recover )
WORKFLOW_recover () {

	SourceStage "setup"

	SourceStage "verify"

	if [ -n "$USE_LAYOUT" ] ; then
		SourceStage "layout/prepare"
		SourceStage "layout/recreate"
	else
		SourceStage "recreate"
	fi

	SourceStage "restore"

	SourceStage "finalize"
	SourceStage "wrapup"
}
