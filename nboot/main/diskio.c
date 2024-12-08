/*-----------------------------------------------------------------------*/
/* Low level disk I/O module skeleton for Petit FatFs (C)ChaN, 2014      */
/*-----------------------------------------------------------------------*/

#include "diskio.h"
#include <common.h>
#include <private_boot0.h>
#include <mmc_boot0.h>

static const int SD_CARD_NUM = 0;

/*-----------------------------------------------------------------------*/
/* Initialize Disk Drive                                                 */
/*-----------------------------------------------------------------------*/

DSTATUS disk_initialize (void)
{
	int bus_width = 4;   // sdcard_info->line_sel[card_no]
	if( sunxi_mmc_init(SD_CARD_NUM, bus_width, BT0_head.prvt_head.storage_gpio, 16) == -1)
		return STA_NOINIT;

	return 0;
}

/*-----------------------------------------------------------------------*/
/* Read Partial Sector                                                   */
/*-----------------------------------------------------------------------*/

DRESULT disk_readp (
	BYTE* buff,		/* Pointer to the destination object */
	DWORD sector,	/* Sector number (LBA) */
	UINT offset,	/* Offset in the sector */
	UINT count		/* Byte count (bit15:destination) */
)
{
	char tmp[512];

	int nsector = mmc_bread(SD_CARD_NUM, sector, 1, tmp); // read 1 sector
	if (nsector != 1) return RES_ERROR; 	// confirm full sector read
	memcpy(buff, tmp + offset, count); 		// copy out desired nbytes at offset
	return 0;
}
