package admin_api_audit_log

import (
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
	"time"
)

/*
CREATE TABLE `admin_api_audit_log` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `tenant_id` int(11) NOT NULL DEFAULT '1',
  `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `user_name` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `action` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `object_id` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `method` varchar(10) COLLATE utf8mb4_bin DEFAULT NULL,
  `request` mediumtext COLLATE utf8mb4_bin,
  `status` smallint(5) NOT NULL,
   KEY `action` (`action`),
   KEY `user_name` (`user_name`),
   KEY `object_id_action` (`object_id`, `action`),
   KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=COMPRESSED;

*/

type AdminApiAuditLog struct {
	ID        int64
	TenantId  int
	CreatedAt time.Time
	UserName  string
	Url       string
	Action    string
	ObjectId  string
	Method    string
	Request   string
	Status    int16
}

func (*AdminApiAuditLog) TableName() string {
	return "admin_api_audit_log"
}

func Add(db *gorm.DB, log *AdminApiAuditLog) error {
	results := db.Create(log)
	return results.Error
}

func (l *AdminApiAuditLog) Add(db *gorm.DB) error {
	return Add(db, l)
}
