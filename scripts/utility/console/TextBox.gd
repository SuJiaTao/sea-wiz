extends RichTextLabel
class_name TextBox


func push(line: String) -> void:
	text += line
	text += "\n"


func clear_text() -> void:
	text = ""
	clear()


func indent(count:int=1) -> void:
	text += "\t".repeat(count)	