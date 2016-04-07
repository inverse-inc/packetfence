update survey SET survey_value = CONCAT('{"old_value":',  survey_value,'}') WHERE concat('', survey_value * 1) = survey_value;
