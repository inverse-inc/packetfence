package aaa

import (
    "testing"
)


func TestIsPublic(t *testing.T) {
    for _, test := range []struct{
                        path string
                        pass bool
                    }{
                        {"/api/v1/translation", false},
                        {"/api/v1/translation/fr", true},
                        {"/api/v1/translations", true},
                    } {
        if isPathPublic(test.path) != test.pass {
            t.Errorf("%s failed public test expected %v",test.path, test.pass);
        }
    }

}
