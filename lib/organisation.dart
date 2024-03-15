import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';


class OrganizationRegistrationScreen extends StatefulWidget {
  @override
  _OrganizationRegistrationScreenState createState() =>
      _OrganizationRegistrationScreenState();
}

class _OrganizationRegistrationScreenState
    extends State<OrganizationRegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _databaseReference =
  FirebaseDatabase.instance.reference().child('organizations');

  PickedFile? _pickedLogo;
  TextEditingController _organizationNameController = TextEditingController();
  TextEditingController _organizationLocationController =
  TextEditingController();

  Future<void> _registerOrganization() async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        if (_organizationNameController.text.isNotEmpty) {
          String logoDownloadURL = "";

          if (_pickedLogo != null) {
            Reference ref = _storage.ref().child('logos/${user.uid}');
            await ref.putFile(File(_pickedLogo!.path!));
            logoDownloadURL = await ref.getDownloadURL();
          }

          DatabaseEvent snapshot =
          await _databaseReference.child(user.uid).once();

          if (snapshot.snapshot.value != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Organization is already registered.'),
              ),
            );
          } else {
            final newOrganization = Organization(
              uid: user.uid,
              name: _organizationNameController.text,
              location: _organizationLocationController.text,
              logoURL: logoDownloadURL,
            );

            _databaseReference.child(user.uid).set(newOrganization.toMap());

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    OrganizationProfileScreen(newOrganization),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please provide the organization name.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not signed in.'),
          ),
        );
      }
    } catch (e) {
      print('Error registering organization: $e');
    }
  }

  void _pickLogo() async {
    final pickedFile =
    await ImagePicker().getImage(source: ImageSource.gallery);

    setState(() {
      _pickedLogo = pickedFile;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Organization Registration'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organization Name:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextField(
                controller: _organizationNameController,
                decoration: InputDecoration(
                  hintText: 'Enter organization name',
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Organization Location:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextField(
                controller: _organizationLocationController,
                decoration: InputDecoration(
                  hintText: 'Enter organization location',
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickLogo,
                child: Text('Pick Logo'),
              ),
              if (_pickedLogo != null) Image.file(File(_pickedLogo!.path)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _registerOrganization,
                child: Text('Register Organization'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Organization organization = Organization(
                    uid: 'organizationUid',
                    name: _organizationNameController.text,
                    location: _organizationLocationController.text,
                    logoURL: _pickedLogo != null
                        ? 'URL to the logo'
                        : '',
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OrganizationProfileScreen(organization),
                    ),
                  );
                },
                child: Text('Organization Profile'),
              ),
            ],

          ),
        ),
      ),
    );
  }
}



class Organization {
  final String uid;
  final String name;
  final String location;
  final String logoURL;

  Organization({
    required this.uid,
    required this.name,
    required this.location,
    required this.logoURL,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'location': location,
      'logoURL': logoURL,
    };
  }
}

class OrganizationProfileScreen extends StatelessWidget {
  final Organization organization;

  OrganizationProfileScreen(this.organization);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Organization Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Name:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(organization.name),
            SizedBox(height: 16),
            Text(
              'Organization Location:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(organization.location),
            SizedBox(height: 16),
            Text(
              'Organization Logo:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Image.network(
              organization.logoURL,
              width: 100,
              height: 100,
            ),
          ],
        ),
      ),
    );
  }
}
