/* -*- mode: c; c-file-style: "gnu" -*-
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <netinet/in.h>

int main() {

  /* startup contains the raw bytes for issuing a TPM startup and
  specifying physical presence. This is needed to clear the compliance
  vectors. This is a TCG command see the TCG specification or page 281
  of "Trusted Platform Module Basics" by Steven Kinney
  */
  char startup[] = {
    0x0, 0xc1,           /* Authorization Tag */
    0x0, 0x0, 0x0, 0xc,  /* Parameter Size */
    0x40, 0x0, 0x0, 0xa, /* Ordinal */
    0x0, 0x8,            /* Startup Type */
  };

  int fd;
  int err;
  int rc = 1;

  fd = open ("/dev/tpm0", O_RDWR);
  if ( fd < 0 )
    {
      printf ("%s\n", "Unable to open the device.");
      goto out_noclose;
    }

  err = write (fd, startup, sizeof (startup));

  if ( err != sizeof (startup) )
    {
      printf( "%s%d\n", "Error occurred while sending command: ", errno );
      goto out;
    }

  rc = 0;
  printf ("%s\n", "Physical presence asserted." );

 out:
  close(fd);

 out_noclose:
  return rc;
}

