import 'package:firebase_database/firebase_database.dart';

final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

Future<void> addQuestions() async {
  Map<String, dynamic> questions = {
    "OOP": {
      "basic": [
        {"question": "What is OOP (Object-Oriented Programming)?", "type": "Basic"},
        {"question": "What are the four principles of OOP?", "type": "Basic"},
        {"question": "What is encapsulation?", "type": "Basic"},
        {"question": "What is abstraction?", "type": "Basic"},
        {"question": "What is polymorphism?", "type": "Basic"},
        {"question": "What is the difference between a class and an object?", "type": "Basic"},
        {"question": "What is a constructor in Java?", "type": "Basic"},
        {"question": "What is the difference between a constructor and a method?", "type": "Basic"},
        {"question": "What are access modifiers in Java?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is the difference between abstraction and encapsulation?", "type": "Intermediate"},
        {"question": "What is the difference between overloading and overriding?", "type": "Intermediate"},
        {"question": "What is the use of the 'this' keyword in Java?", "type": "Intermediate"},
        {"question": "What is the 'super' keyword in Java?", "type": "Intermediate"},
        {"question": "What is the difference between an interface and an abstract class?", "type": "Intermediate"},
        {"question": "What is the 'final' keyword in Java?", "type": "Intermediate"},
        {"question": "What is the 'static' keyword in Java?", "type": "Intermediate"},
        {"question": "What are static methods and variables in Java?", "type": "Basic"}
      ]
    },
    "Inheritance": {
      "basic": [
        {"question": "What is inheritance in Java?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is method overriding?", "type": "Intermediate"},
        {"question": "What is the use of the 'final' keyword with a class or method?", "type": "Intermediate"}
      ]
    },
    "Polymorphism": {
      "basic": [
        {"question": "What is polymorphism?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is method overloading?", "type": "Intermediate"},
        {"question": "What is method overriding?", "type": "Intermediate"},
        {"question": "What is the difference between overloading and overriding?", "type": "Intermediate"}
      ]
    },
    "Encapsulation": {
      "basic": [
        {"question": "What is encapsulation?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is the difference between abstraction and encapsulation?", "type": "Intermediate"}
      ]
    },
    "Abstraction": {
      "basic": [
        {"question": "What is abstraction?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is the difference between an interface and an abstract class?", "type": "Intermediate"}
      ]
    },
    "Classes and Objects": {
      "basic": [
        {"question": "What is a class in Java?", "type": "Basic"},
        {"question": "What is an object in Java?", "type": "Basic"},
        {"question": "What is the difference between a class and an object?", "type": "Basic"},
        {"question": "What is a constructor in Java?", "type": "Basic"},
        {"question": "What is the difference between a constructor and a method?", "type": "Basic"}
      ]
    },
    "Access Modifiers and Keywords": {
      "basic": [
        {"question": "What are access modifiers in Java?", "type": "Basic"},
        {"question": "What is the difference between public, private, protected, and default access modifiers?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is the use of the 'this' keyword in Java?", "type": "Intermediate"},
        {"question": "What is the 'super' keyword in Java?", "type": "Intermediate"},
        {"question": "What is the 'final' keyword in Java?", "type": "Intermediate"},
        {"question": "What is the 'static' keyword in Java?", "type": "Intermediate"},
        {"question": "What are static methods and variables in Java?", "type": "Basic"}
      ]
    },
    "Strings and String Manipulation": {
      "intermediate": [
        {"question": "What is the difference between String, StringBuilder, and StringBuffer?", "type": "Intermediate"}
      ]
    },
    "Wrapper Classes and Autoboxing": {
      "basic": [
        {"question": "What are wrapper classes in Java?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is autoboxing and unboxing in Java?", "type": "Intermediate"}
      ]
    },
    "Exception Handling": {
      "basic": [
        {"question": "What is exception handling in Java?", "type": "Basic"},
        {"question": "What are try, catch, and finally blocks in Java?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is the difference between checked and unchecked exceptions?", "type": "Intermediate"},
        {"question": "What is the use of the throw and throws keyword?", "type": "Intermediate"}
      ]
    },
    "Multithreading": {
      "intermediate": [
        {"question": "What is multithreading in Java?", "type": "Intermediate"},
        {"question": "What is the difference between Thread and Runnable in Java?", "type": "Intermediate"}
      ],
      "hard": [
        {"question": "What is the synchronized keyword in Java?", "type": "Hard"},
        {"question": "What is the volatile keyword in Java?", "type": "Hard"}
      ]
    },
    "Functional Programming (Java 8+)": {
      "intermediate": [
        {"question": "What are lambda expressions in Java?", "type": "Intermediate"},
        {"question": "What is the Stream API in Java?", "type": "Intermediate"},
        {"question": "What is the Optional class in Java?", "type": "Intermediate"}
      ]
    },
    "Collections and Data Structures": {
      "intermediate": [
        {"question": "What is the difference between ArrayList and LinkedList?", "type": "Intermediate"},
        {"question": "What is the difference between HashMap and Hashtable?", "type": "Intermediate"}
      ]
    },
    "Equality and Comparison": {
      "basic": [
        {"question": "What is the difference between == and equals()?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is the difference between == operator and the equals() method?", "type": "Intermediate"}
      ]
    },
    "Memory Management": {
      "basic": [
        {"question": "What is garbage collection in Java?", "type": "Intermediate"},
        {"question": "What is the role of the JVM (Java Virtual Machine)?", "type": "Basic"}
      ]
    },
    "Java Basics": {
      "basic": [
        {"question": "What is JDK, JRE, and JVM?", "type": "Basic"},
        {"question": "What is the main() method in Java?", "type": "Basic"}
      ]
    },
    "Packages and Imports": {
      "basic": [
        {"question": "What is a package in Java?", "type": "Basic"}
      ],
      "intermediate": [
        {"question": "What is the difference between import and static import in Java?", "type": "Intermediate"}
      ]
    },
    "Design Patterns": {
      "hard": [
        {"question": "What are design patterns in Java, and can you name a few common ones?", "type": "Hard"}
      ]
    }
  };

  // Save questions to Firebase
  await _dbRef.child("questions").set(questions);
}

