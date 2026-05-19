import CoreData
import Foundation



extension NSManagedObject {
	
	static func existingFrom(id: NSManagedObjectID, in context: NSManagedObjectContext) throws -> Self {
		guard let ret = try context.existingObject(with: id) as? Self else {
			throw NSError(domain: Constants.appDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot object with id \(id) does not have type \(self)"])
		}
		return ret
	}
	
}
