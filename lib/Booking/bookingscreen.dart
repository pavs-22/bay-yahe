import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/History/historyscreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

final _db = FirebaseFirestore.instance;
final CollectionReference bookingDetails =
    FirebaseFirestore.instance.collection('booking_details');
final FirebaseAuth _auth = FirebaseAuth.instance;
final User? currentUser = _auth.currentUser;
final String driverId = currentUser?.phoneNumber ?? "";
const String status = "accepted";
final String updateStatus = "done";

class BookingTab extends StatefulWidget {
  const BookingTab({Key? key}) : super(key: key);

  @override
  State<BookingTab> createState() => _BookingTabState();
}

class _BookingTabState extends State<BookingTab> {
  late List<Map<String, dynamic>> bookingHistory;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBookingHistory();
  }

  void fetchBookingHistory() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await bookingDetails
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: status)
          .get() as QuerySnapshot<Map<String, dynamic>>;

      setState(() {
        bookingHistory = querySnapshot.docs.map((doc) => doc.data()).toList();
        isLoading = false;
      });
    } catch (error) {
      print("Error fetching data: $error");
      isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Going Booking'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.3, -0.3),
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green],
          ),
        ),
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : bookingHistory.isEmpty
                ? Center(child: Text('No booking history available'))
                : ListView.builder(
                    itemCount: bookingHistory.length,
                    itemBuilder: (context, index) {
                      final data = bookingHistory[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: ListTile(
                          title: Text(
                            'Travel: ${data['pickupLocation'] ?? 'N/A'} - ${data['destination'] ?? 'N/A'}',
                          ),
                          subtitle: Text(formatTimestamp(data['bookingTime'])),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingDetailsScreen(
                                  bookingData: data,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String formatTimestamp(Timestamp timestamp) {
    final philippinesTime = timestamp.toDate().add(const Duration(hours: 8));
    final formatter = DateFormat.yMMMMd().add_jm();
    return formatter.format(philippinesTime);
  }
}

class BookingDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const BookingDetailsScreen({Key? key, required this.bookingData})
      : super(key: key);

  Future<Map<String, dynamic>> fetchDriverData(String driverId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('driver_user')
              .where('uid', isEqualTo: driverId)
              .get() as QuerySnapshot<Map<String, dynamic>>;

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
    } catch (error) {
      print("Error fetching driver data: $error");
    }
    return {};
  }

  Future<Map<String, dynamic>> fetchPassengerData(String passengerId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('client_user')
              .where('userId', isEqualTo: passengerId)
              .get() as QuerySnapshot<Map<String, dynamic>>;

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
    } catch (error) {
      print("Error fetching passenger data: $error");
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF33c072),
        title: const Text('Booking Details'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.3, -0.3),
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green],
          ),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: fetchDriverData(bookingData['driverId']),
          builder: (context, driverSnapshot) {
            if (driverSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (driverSnapshot.hasError) {
              return Center(child: Text('Error loading driver data'));
            } else if (!driverSnapshot.hasData ||
                driverSnapshot.data!.isEmpty) {
              return Center(child: Text('Driver data not found'));
            }

            return FutureBuilder<Map<String, dynamic>>(
              future: fetchPassengerData(bookingData['userId']),
              builder: (context, passengerSnapshot) {
                if (passengerSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (passengerSnapshot.hasError) {
                  return Center(child: Text('Error loading passenger data'));
                } else if (!passengerSnapshot.hasData ||
                    passengerSnapshot.data!.isEmpty) {
                  return Center(child: Text('Passenger data not found'));
                }

                var passengerData = passengerSnapshot.data!;

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BookingDetailItem(
                              label: 'Your Ride Details',
                              value: 'Travel Preview',
                            ),
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    bookingData['pickupLoc']['latitude'],
                                    bookingData['pickupLoc']['longitude'],
                                  ),
                                  zoom: 12.0,
                                ),
                                markers: Set<Marker>.from([
                                  Marker(
                                    markerId: MarkerId('pickup_location'),
                                    position: LatLng(
                                      bookingData['pickupLoc']['latitude'],
                                      bookingData['pickupLoc']['longitude'],
                                    ),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueRed),
                                    infoWindow: InfoWindow(
                                      title: 'Pickup Location',
                                    ),
                                  ),
                                  Marker(
                                    markerId: MarkerId('destination_location'),
                                    position: LatLng(
                                      bookingData['destinationLoc']['latitude'],
                                      bookingData['destinationLoc']
                                          ['longitude'],
                                    ),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueGreen),
                                    infoWindow: InfoWindow(
                                      title: 'Destination Location',
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            BookingDetailItem(
                              label: 'Date & Time',
                              value:
                                  formatTimestamp(bookingData['bookingTime']),
                            ),
                            BookingDetailItem(
                              label: 'Travel Cost',
                              value: bookingData['fareprice'],
                            ),
                            BookingDetailItem(
                              label: 'Passenger',
                              value: bookingData['contactPerson'],
                            ),
                            BookingDetailItem(
                              label: 'Contact',
                              value: bookingData['contactNumber'],
                            ),
                            BookingDetailItem(
                              label: 'Travel',
                              value:
                                  'from : ${bookingData['pickupLocation']} \n to : ${bookingData['destination']}',
                            ),
                            BookingDetailItem(
                              label: 'Fare',
                              value: bookingData['fareType'],
                            ),
                            BookingDetailItem(
                              label: 'Type',
                              value:
                                  '${bookingData['passengerType']} passenger',
                            ),
                            BookingDetailItem(
                              label: 'Mode of Payment',
                              value: bookingData['paymentMethod'],
                            ),
                            BookingDetailItem(
                              label: 'Passenger Profile',
                              value:
                                  Image.network(passengerData['profile_image']),
                            ),
                            BookingDetailItem(
                              label: 'Name',
                              value:
                                  '${passengerData['firstname']} ${passengerData['lastname']}',
                            ),
                            BookingDetailItem(
                              label: 'Reference Number',
                              value: bookingData['transactionID'],
                            ),
                            Center(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection("booking_details")
                                      .where("transactionID",
                                          isEqualTo:
                                              bookingData['transactionID'])
                                      .get()
                                      .then(
                                    (querySnapshot) {
                                      for (var doc in querySnapshot.docs) {
                                        doc.reference.update({
                                          'status': updateStatus,
                                        });
                                      }
                                    },
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HistoryTab(),
                                    ),
                                  );
                                },
                                child: Text('Finish'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String formatTimestamp(Timestamp timestamp) {
  final philippinesTime = timestamp.toDate().add(const Duration(hours: 8));
  final formatter = DateFormat.yMMMMd().add_jm();
  return formatter.format(philippinesTime);
}

class BookingDetailItem extends StatelessWidget {
  final String label;
  final dynamic value; // Accept dynamic type to handle both String and Image

  const BookingDetailItem({Key? key, required this.label, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          value is String
              ? Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                )
              : (value is Image)
                  ? value // Display Image widget directly
                  : Text('Invalid value type'),
        ],
      ),
    );
  }
}
