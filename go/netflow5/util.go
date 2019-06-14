package netflow5

import "unsafe"

func ntoh16(n uint16) uint16 {
	buff := (*[2]byte)(unsafe.Pointer(&n))
	return (uint16(buff[0]) << 8) | uint16(buff[1])
}

func ntoh32(n uint32) uint32 {
	buff := (*[4]byte)(unsafe.Pointer(&n))
	return (uint32(buff[0]) << 24) | (uint32(buff[1]) << 16) | (uint32(buff[2]) << 8) | uint32(buff[3])
}

func ntoh64(n uint64) uint64 {
	buff := (*[8]byte)(unsafe.Pointer(&n))
	return (uint64(buff[0]) << 56) | (uint64(buff[1]) << 48) | (uint64(buff[2]) << 40) | (uint64(buff[3]) << 32) |
		(uint64(buff[4]) << 24) | (uint64(buff[5]) << 16) | (uint64(buff[6]) << 8) | uint64(buff[7])
}
