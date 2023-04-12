package models

type Err struct {
	Message string `json:"message"`
}

type DBRes struct {
	Item       interface{} `json:"item,omitempty"`
	Items      interface{} `json:"items,omitempty"`
	Total      *int        `json:"total,omitempty"`
	NextCursor *int        `json:"nextCursor,omitempty"`
	PrevCursor *int        `json:"prevCursor,omitempty"`
}

const dbError = "a database error occured. see logs for details"
