extends RichTextLabel
class_name TextBox


func push(line: String) -> void:
	text += line
	text += "\n"


func clear_text() -> void:
	text = ""
	clear()
