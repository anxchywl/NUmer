file_path = 'lib/screens/habits/add_habit_sheet.dart'
with open(file_path, 'r') as f:
    content = f.read()

def count_mismatches(text):
    stack = []
    pairs = {')': '(', '}': '{', ']': '['}
    for char in text:
        if char in '({[':
            stack.append(char)
        elif char in ')}]':
            if not stack or stack[-1] != pairs[char]:
                print(f"Mismatch: found {char} but stack is {stack[-1] if stack else 'empty'}")
                return False
            stack.pop()
    print(f"Stack at end: {stack}")
    return len(stack) == 0

count_mismatches(content)
